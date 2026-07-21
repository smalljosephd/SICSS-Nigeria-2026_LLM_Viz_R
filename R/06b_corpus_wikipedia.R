# =============================================================================
# 06b_corpus_wikipedia.R  |  Build a dated corpus from yearly article snapshots
# -----------------------------------------------------------------------------
# Fetches one version of an article per year and returns them as dated
# documents, ready for the topic model.
#
# HOW THIS CONNECTS TO THE MORNING SESSION. You've (likely) scraped Wikipedia
# article text and revision history. 
# This uses both: the revision history tells us which
# version existed in a given year, and we take the text of that version.
#
# WHAT WE ARE NOT USING, and why:
#   Edit comments     mostly process language (reverted vandalism, fixed
#                     citation). Interesting sociologically, but not about
#                     the subject of the article.
#   Every revision    consecutive revisions are nearly identical, which gives
#                     thousands of near-duplicate documents and a flat chart.
#   Diffs             closest to what we want, and by far the most work to
#                     clean. Not worth it for a two-hour session.
#
# One version per year is the compromise: few enough documents to fit quickly,
# far enough apart that the text has genuinely changed.
#
# RUN 06a_check_snapshots.R FIRST. It tells you whether this article changed
# enough to be worth the effort.
#
# No account or key needed. Reading the Wikipedia API is open.
#
# Sourced by 06_load_corpus.R. Can also be run on its own.
# =============================================================================

if (!exists("SEED")) source("R/00_setup.R")
if (!exists("clean_wikitext")) source("R/utils.R")

## ---- Settings ----------------------------------------------------------------
## KEEP THIS THE SAME AS ARTICLE_TITLE IN 00_setup.R. One article runs through
## the whole session: Part 1 asks what it says, Part 2 asks how that changed.
## If you change one, change the other, or the two halves come apart.
WIKI_ARTICLE   <- ARTICLE_TITLE
WIKI_YEARS     <- 2005:2025
WIKI_MONTH_DAY <- "-06-01"     # mid-year, to avoid quiet periods around January
WIKI_MIN_WORDS <- 300          # ignore snapshots too short to model

cat("Article:", WIKI_ARTICLE, "\n")
cat("Years  :", min(WIKI_YEARS), "to", max(WIKI_YEARS),
    "(", length(WIKI_YEARS), "requests )\n\n")

## ---- Fetch, one year at a time -----------------------------------------------
## Cached, because twenty requests take a couple of minutes and there is no
## reason to repeat them. Delete the file to fetch again.
slug <- tolower(gsub("[^A-Za-z0-9]+", "_", WIKI_ARTICLE))
slug <- gsub("^_|_$", "", slug)
snap_cache <- file.path("cache", paste0("snapshots_", slug, ".rds"))

snapshots <- cache_or_run(snap_cache, {

  rows <- list()

  for (yr in WIKI_YEARS) {
    cat(sprintf("  %d ... ", yr))

    ## tryCatch keeps one failed request from ending the whole run. A dropped
    ## connection on year 12 should not cost you the first eleven.
    rev <- tryCatch(
      fetch_revision_at(WIKI_ARTICLE, paste0(yr, WIKI_MONTH_DAY)),
      error = function(e) { cat("failed (", conditionMessage(e), ")\n"); NULL }
    )

    if (is.null(rev)) { cat("no revision\n"); next }

    clean <- clean_wikitext(rev$text)
    n_w   <- str_count(clean, "\\S+")

    if (n_w < WIKI_MIN_WORDS) {
      cat("too short (", n_w, "words )\n"); next
    }

    rows[[length(rows) + 1]] <- tibble(
      Year      = yr,
      timestamp = rev$timestamp,
      text      = clean,
      n_words   = n_w
    )
    cat(format(n_w, big.mark = ","), "words\n")

    Sys.sleep(0.3)   # polite spacing between requests
  }

  if (length(rows) == 0) {
    stop("No snapshots retrieved. Check the article title and your connection.")
  }

  bind_rows(rows)
})

cat("\nSnapshots:", nrow(snapshots), "\n")
cat("Years    :", min(snapshots$Year), "to", max(snapshots$Year), "\n")
cat("Words    :", format(min(snapshots$n_words), big.mark = ","), "to",
    format(max(snapshots$n_words), big.mark = ","), "\n")

if (nrow(snapshots) < 8) {
  warning("Only ", nrow(snapshots), " snapshots. A topic model needs more ",
          "documents than themes to be worth fitting. Consider widening ",
          "WIKI_YEARS, or using the tweet corpus instead.")
}

## ---- Split each snapshot into chunks -----------------------------------------
## This step matters more than it looks. Twenty long documents is too few for a
## topic model: it gives each document its own topic, and the chart then shows
## which year is which rather than which themes run through the article.
##
## Cutting each snapshot into pieces of about 300 words turns twenty documents
## into several hundred. Every chunk keeps its year, so the time information is
## untouched, but themes now have to appear across many chunks to be found.
CHUNK_WORDS <- 300

corpus_df <- snapshots %>%
  rowwise() %>%
  mutate(piece = list(chunk_text(text, words_per_chunk = CHUNK_WORDS))) %>%
  ungroup() %>%
  select(Year, piece) %>%
  tidyr::unnest(piece) %>%
  rename(text = piece) %>%
  arrange(Year)

cat("\nChunks of about", CHUNK_WORDS, "words:", nrow(corpus_df), "documents\n")

chunks_per_year <- corpus_df %>% count(Year)
cat("Per year:", min(chunks_per_year$n), "to", max(chunks_per_year$n), "chunks\n")

if (nrow(corpus_df) < 100) {
  warning("Only ", nrow(corpus_df), " chunks. The topic model may still assign ",
          "one topic per document. Lower CHUNK_WORDS, or widen WIKI_YEARS.")
}

## Words to drop beyond ordinary stop-words. Two kinds here: leftovers from
## wiki markup that survive cleaning, and the article's own subject terms,
## which would otherwise lead every theme and tell you nothing.
EXTRA_STOP <- c(
  ## markup leftovers
  "ref", "cite", "http", "https", "www", "isbn", "pdf", "jpg", "png",
  "align", "style", "width", "thumb", "left", "right", "center",
  "url", "archive", "retrieved", "accessdate", "publisher",
  ## very common words that survive the standard stop-word list and add nothing
  "also", "made", "would", "could", "one", "two", "many", "however",
  "later", "following", "including", "although",
  ## the subject itself. Left in, these lead every theme and say nothing,
  ## because they appear in nearly every paragraph. Adjust if you change
  ## articles: for "End SARS" you would drop "sars", "police", "protest".
  "nigeria", "nigerian", "war", "civil"
)

CORPUS_LABEL <- paste0("\u201C", WIKI_ARTICLE, "\u201D on Wikipedia, ",
                       min(snapshots$Year), " to ", max(snapshots$Year))
CORPUS_WHICH <- "wikipedia"

## A note worth making in the session: the article's own name is in the
## stop-word list. Left in, "nigeria" would appear in every theme, because it
## appears in every paragraph. Removing the obvious is part of preparing text,
## and the choice of what counts as obvious is yours to defend.
