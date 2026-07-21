# =============================================================================
# utils.R  |  Helper functions shared by several scripts
# -----------------------------------------------------------------------------
# Sourced by the numbered scripts. Contains nothing that runs on its own --
# only function definitions, so sourcing it is always safe.
# =============================================================================


# -----------------------------------------------------------------------------
# cache_or_run()
# -----------------------------------------------------------------------------
# Runs an expression once, saves the result, and reuses the saved copy after
# that. Used for every slow step (language-model calls, topic-model fitting,
# embeddings) so the session never waits on work already done.
#
#   path     where to save the result
#   expr     the code to run if no saved copy exists
#   refresh  set TRUE to ignore the saved copy and run again
#
# Example:
#   result <- cache_or_run("cache/extraction.rds", {
#     chat$chat_structured(prompt, type = schema)
#   })
#
# To redo a cached step, either pass refresh = TRUE or delete the file.
# -----------------------------------------------------------------------------
cache_or_run <- function(path, expr, refresh = FALSE) {
  if (!refresh && file.exists(path)) {
    message("Loading cached: ", path)
    return(readRDS(path))
  }
  message("Computing (not cached): ", path)
  result <- expr          # expr is evaluated here, on first use
  saveRDS(result, path)
  result
}


# -----------------------------------------------------------------------------
# fetch_wikipedia()
# -----------------------------------------------------------------------------
# Downloads the plain-text body of one Wikipedia article through the public
# API. Returns a single character string. Needs an internet connection.
#
#   explaintext = 1  asks for readable text rather than HTML or wiki markup
#   redirects   = 1  follows redirects, so a short title finds the right page
# -----------------------------------------------------------------------------
fetch_wikipedia <- function(title) {
  request("https://en.wikipedia.org/w/api.php") |>
    req_url_query(action      = "query",
                  prop        = "extracts",
                  explaintext = "1",
                  format      = "json",
                  redirects   = "1",
                  titles      = title) |>
    req_user_agent("SICSS-Nigeria 2026 teaching session") |>
    req_perform() |>
    resp_body_json() |>
    (\(j) j$query$pages[[1]]$extract)()
}


# -----------------------------------------------------------------------------
# clean_wiki()
# -----------------------------------------------------------------------------
# Removes the parts of an article that are not prose: the closing sections
# (See also, References, External links) and the "== Heading ==" markers.
# Also drops bracketed asides, which are usually pronunciations or notes,
# and flattens all whitespace to single spaces.
# -----------------------------------------------------------------------------
clean_wiki <- function(txt) {
  txt |>
    str_remove_all("(?s)== See also ==.*$") |>
    str_remove_all("(?s)== References ==.*$") |>
    str_remove_all("(?s)== External links ==.*$") |>
    str_remove_all("(?s)== Notes ==.*$") |>
    str_remove_all("==+[^=]+==+") |>
    str_replace_all("\\([^)]*\\)", " ") |>
    str_replace_all("\\s+", " ") |>
    str_squish()
}


# -----------------------------------------------------------------------------
# load_wikitext()
# -----------------------------------------------------------------------------
# Reads a WikiText-2 file into one row per article.
#
# WikiText-2 marks article titles with single equals signs ( = Title = ) and
# section headings with doubled ones ( = = Section = = ). Two patterns are
# needed: one to find where each article starts, and one to remove every
# heading line so no heading text ends up inside the article body.
#
# Checked against the real wiki.valid.tokens: 60 articles, no headings left in
# the text.
# -----------------------------------------------------------------------------
load_wikitext <- function(path) {
  lines <- read_lines(path, locale = locale(encoding = "UTF-8"))

  is_title <- str_detect(lines, "^\\s*= [^=].+[^=] =\\s*$")  # article starts
  is_head  <- str_detect(lines, "^\\s*=.*=\\s*$")            # any heading line

  titles <- str_squish(str_remove_all(lines[is_title], "="))

  tibble(doc_id = cumsum(is_title), text = lines) |>
    filter(!is_head, str_squish(text) != "") |>
    mutate(text = str_replace_all(text, "@-@", "-")) |>   # restore hyphens
    group_by(doc_id) |>
    summarise(text = paste(str_squish(text), collapse = " "), .groups = "drop") |>
    filter(doc_id > 0) |>
    mutate(title = titles[doc_id])
}


# -----------------------------------------------------------------------------
# sentence_cooccurrence()
# -----------------------------------------------------------------------------
# Turns one document into word pairs.
#
# Counting co-occurrence needs several documents to compare. With a single
# article we treat each SENTENCE as a small document, so two words are linked
# when they share a sentence.
#
#   txt        the article text
#   top_n      how many of the most frequent words to keep (keeps graphs legible)
#   min_chars  shortest word to keep
# -----------------------------------------------------------------------------
sentence_cooccurrence <- function(txt, top_n = 30, min_chars = 4) {

  sentences <- tibble(text = txt) |>
    unnest_tokens(sentence, text, token = "sentences") |>
    mutate(sent_id = row_number())

  sent_words <- sentences |>
    unnest_tokens(word, sentence) |>
    anti_join(get_stopwords(), by = "word") |>
    filter(str_detect(word, "^[a-z]+$"), nchar(word) >= min_chars)

  keep <- sent_words |>
    count(word, sort = TRUE) |>
    slice_head(n = top_n) |>
    pull(word)

  sent_words |>
    filter(word %in% keep) |>
    pairwise_count(item = word, feature = sent_id, sort = TRUE, upper = FALSE)
}


# -----------------------------------------------------------------------------
# build_relation_graph()
# -----------------------------------------------------------------------------
# Turns a table of subject / relation / object rows into a directed graph.
#
# One detail that causes silent errors: graph_from_data_frame() takes the FIRST
# TWO COLUMNS as the two ends of each edge, whatever they are called. So the
# columns must be reordered, not merely renamed -- select() does both, rename()
# only renames and leaves the wrong column in position two.
# -----------------------------------------------------------------------------
build_relation_graph <- function(relations) {
  relations |>
    filter(subject != "", object != "", !is.na(subject), !is.na(object)) |>
    select(from = subject, to = object, relation) |>
    graph_from_data_frame(directed = TRUE) |>
    as_tbl_graph()
}


# -----------------------------------------------------------------------------
# save_figure()
# -----------------------------------------------------------------------------
# Writes a figure to prebuilt/ at a consistent size. Keep these images open
# during the session: if live code fails, show the picture and keep talking.
# -----------------------------------------------------------------------------
save_figure <- function(plot, name, width = 9, height = 6) {
  path <- file.path("prebuilt", paste0(name, ".png"))
  ggsave(path, plot, width = width, height = height, dpi = 150)
  message("Saved: ", path)
  invisible(path)
}

# -----------------------------------------------------------------------------
# fetch_revision_at()
# -----------------------------------------------------------------------------
# Returns the article as it stood on or just after a given date.
#
# The MediaWiki API is public: no key, no account. It does ask that requests
# identify themselves, which is what req_user_agent() below does. Requests
# without one can be refused.
#
#   title  article name, e.g. "Nigerian Civil War"
#   date   "YYYY-MM-DD"
#
# Returns a list with timestamp and text (raw wikitext), or NULL if the article
# did not exist yet on that date.
#
# Note on the format: this returns RAW WIKITEXT, not plain prose. The tidy
# plain-text endpoint used in script 01 only works on the current version of a
# page. Historical revisions arrive with templates, reference tags and markup
# still in place, which is why clean_wikitext() exists below.
# -----------------------------------------------------------------------------
fetch_revision_at <- function(title, date) {

  resp <- request("https://en.wikipedia.org/w/api.php") |>
    req_url_query(
      action  = "query",
      prop    = "revisions",
      titles  = title,
      rvstart = paste0(date, "T00:00:00Z"),
      rvdir   = "newer",          # first revision AT OR AFTER that date
      rvlimit = 1,
      rvprop  = "timestamp|content",
      rvslots = "main",
      format  = "json",
      formatversion = 2
    ) |>
    req_user_agent("SICSS-Nigeria 2026 teaching session") |>
    req_timeout(60) |>
    req_retry(max_tries = 3) |>   # connections drop; try again rather than stop
    req_perform()

  page <- resp_body_json(resp)$query$pages[[1]]

  if (is.null(page$revisions) || length(page$revisions) == 0) return(NULL)

  rev <- page$revisions[[1]]
  list(timestamp = rev$timestamp,
       text      = rev$slots$main$content)
}


# -----------------------------------------------------------------------------
# clean_wikitext()
# -----------------------------------------------------------------------------
# Strips wiki markup down to readable prose.
#
# Raw wikitext carries a great deal that is not article text: infobox
# templates, citation templates, reference tags, image links, category links,
# table markup. Left in, all of it would be counted as words by the topic
# model, and template vocabulary would swamp the actual writing.
#
# The order of the steps matters. Templates are removed before links, because
# templates often contain links. Reference tags go before general HTML, because
# they have contents worth removing rather than keeping.
#
# Checked against realistic markup: templates, refs, files, categories, URLs,
# bold marks, headings, tables and HTML entities all removed, while ordinary
# link text and body prose are kept.
# -----------------------------------------------------------------------------
clean_wikitext <- function(txt) {

  if (is.null(txt) || length(txt) == 0) return("")
  if (is.na(txt) || !nzchar(txt))       return("")
  x <- txt

  ## editorial comments, invisible on the page
  x <- str_remove_all(x, "(?s)<!--.*?-->")

  ## reference tags, with their contents
  x <- str_remove_all(x, "(?s)<ref[^>]*/>")
  x <- str_remove_all(x, "(?s)<ref[^>]*>.*?</ref>")

  ## block elements whose contents are not prose
  x <- str_remove_all(x, "(?s)<(table|gallery|imagemap|timeline|math)[^>]*>.*?</\\1>")
  ## remaining HTML tags: drop the tag, keep any text
  x <- str_remove_all(x, "<[^>]{1,200}>")

  ## templates {{...}}. Removing innermost first and repeating handles nesting,
  ## which is common: an infobox containing citations containing dates.
  for (i in 1:12) {
    before <- x
    x <- str_remove_all(x, "\\{\\{[^{}]*\\}\\}")
    if (identical(before, x)) break
  }
  x <- str_remove_all(x, "\\{\\|(?s).*?\\|\\}")   # wiki tables
  x <- str_remove_all(x, "[{}]")                    # unbalanced leftovers

  ## images and media: remove the whole link, caption included
  x <- str_remove_all(x, "\\[\\[(?i:File|Image|Media)\\s*:[^\\]]*\\]\\]")

  ## category and interwiki links carry no prose
  x <- str_remove_all(x, "\\[\\[(?i:Category)\\s*:[^\\]]*\\]\\]")
  x <- str_remove_all(x, "\\[\\[[a-z]{2,3}:[^\\]]*\\]\\]")

  ## internal links: keep the words a reader would see
  ##   [[Niger Delta|the delta]]  ->  the delta
  ##   [[Nigeria]]                ->  Nigeria
  x <- str_replace_all(x, "\\[\\[[^\\]|]*\\|([^\\]]*)\\]\\]", "\\1")
  x <- str_replace_all(x, "\\[\\[([^\\]]*)\\]\\]", "\\1")

  ## external links: keep the label, drop the address
  x <- str_replace_all(x, "\\[https?://\\S+\\s+([^\\]]*)\\]", "\\1")
  x <- str_remove_all(x, "\\[https?://[^\\]]*\\]")
  x <- str_remove_all(x, "https?://\\S+")

  ## the appendix sections and everything after them
  x <- str_remove(x, "(?is)\\n==+\\s*(see also|references|notes|further reading|external links|bibliography|sources|citations)\\s*==+.*$")

  ## heading lines themselves
  x <- str_remove_all(x, "(?m)^\\s*=+[^=\\n]+=+\\s*$")

  ## formatting marks and list bullets
  x <- str_remove_all(x, "'{2,5}")
  x <- str_remove_all(x, "(?m)^[*#:;]+\\s*")
  x <- str_remove_all(x, "(?m)^\\s*\\|.*$")
  x <- str_remove_all(x, "(?m)^\\s*!.*$")

  ## HTML entities
  x <- str_replace_all(x, "&nbsp;", " ")
  x <- str_replace_all(x, "&amp;", "&")
  x <- str_replace_all(x, "&quot;", "\"")
  x <- str_replace_all(x, "&[a-z]{2,8};", " ")

  ## collapse whitespace
  x <- str_replace_all(x, "\\s+", " ")
  str_squish(x)
}


# -----------------------------------------------------------------------------
# chunk_text()
# -----------------------------------------------------------------------------
# Splits one long document into several shorter ones of roughly equal length.
#
# WHY THIS IS NEEDED. A topic model works out themes by seeing which words keep
# company ACROSS documents. Give it twenty very long documents and it has too
# little to compare: it tends to hand each document its own topic, so every row
# of theta is close to 1 for one topic and 0 for the rest. The chart then shows
# which document is which, not which themes run through them.
#
# Splitting each yearly snapshot into chunks turns twenty documents into several
# hundred. Themes then have to be shared across chunks to be found at all, and
# each year's share becomes an average over its chunks rather than a near
# certainty.
#
#   words_per_chunk  target length. 250 to 400 works well for article prose.
#   min_words        chunks shorter than this are dropped as too thin to model.
#
# The final chunk is folded into the one before it when it would fall below
# min_words, so no text is discarded.
# -----------------------------------------------------------------------------
chunk_text <- function(txt, words_per_chunk = 300, min_words = 120) {

  w <- str_split(str_squish(txt), " ")[[1]]
  w <- w[nzchar(w)]
  if (length(w) < min_words) return(character(0))

  idx <- ceiling(seq_along(w) / words_per_chunk)
  out <- unname(vapply(split(w, idx), paste, character(1), collapse = " "))

  keep <- str_count(out, "\\S+") >= min_words

  ## fold a short tail into the previous chunk rather than losing it
  if (length(out) > 1 && !keep[length(out)]) {
    out[length(out) - 1] <- paste(out[length(out) - 1], out[length(out)])
    out  <- out[-length(out)]
    keep <- keep[-length(keep)]
    keep[length(keep)] <- TRUE
  }

  out[keep]
}
