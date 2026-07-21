# =============================================================================
# 03_llm_extraction.R  |  Ask the model for entities and relationships
# -----------------------------------------------------------------------------
# The model reads the same article script 02 counted, and returns two tables:
# the things named in the text, and how they relate to each other.
#
# TWO IDEAS DO THE WORK HERE.
#
# THE SCHEMA -- the shape of the answer.
#   Normally you ask a model a question and get a paragraph back, which you
#   then have to pick apart. Instead we hand it a blank form and ask it to fill
#   the form in. The form here has two parts: a list of entities, each with a
#   name and a type; and a list of relationships, each with a subject, a
#   relation and an object. Because the shape is fixed in advance, the answer
#   arrives as data frames that go straight into a graph. No text to unpick.
#
#   type_string()  one text field, like a blank line on a form
#   type_object()  a group of fields that belong together, like one record
#   type_array()   many of those records
#
# THE PROMPT -- what to look for.
#   The schema fixes the shape; the prompt decides the content. Asking for
#   "entities and relationships" gets very different answers from a country
#   article than from an election article, and a prompt written for one will
#   underperform on the other. So the prompt below changes with the article.
#   This is worth showing in the session: the prompt is part of the method,
#   not an afterthought.
#
# RUN THIS BEFORE THE SESSION. The answer is cached, so on the day it loads
# from disk in an instant.
#
# Needs   :  cache/article.rds, Ollama running with the model pulled
# Produces:  cache/extraction_<article>.rds
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

article <- readRDS("cache/article.rds")
cat("Article:", article$title, "|", article$n_chars, "characters\n")

## ---- The schema: the shape of the answer -------------------------------------
## One entity: what it is called, and what kind of thing it is.
type_entity <- type_object(
  name = type_string("Entity name as written in the text, e.g. Lagos, Bola Tinubu"),
  type = type_string("One of: Person, Place, Organisation, Event")
)

## One relationship: three parts, read as a sentence.
##   subject -> relation -> object
##   "Lagos" -> "is the largest city in" -> "Nigeria"
type_relation <- type_object(
  subject  = type_string("The entity the statement is about"),
  relation = type_string("Short verb phrase, e.g. is the capital of, member of"),
  object   = type_string("The entity the subject relates to")
)

## The whole form: many entities, and many relationships.
type_extraction <- type_object(
  entities  = type_array(type_entity),
  relations = type_array(type_relation)
)

## ---- The prompt: what to look for --------------------------------------------
## Different articles hold different kinds of relationship, so the instruction
## changes with the article. A country article is about geography and
## institutions; an election article is about candidates, parties and results.
## Asking the same question of both wastes the model's attention.
##
## To add your own article: add a case here, and set ARTICLE_TITLE in
## 00_setup.R to match.

focus_by_article <- list(

  ## The session's main article. A war article is dense with actors, places
  ## and organisations, and the relationships worth pulling out are about who
  ## fought whom, who led what, and which places were involved.
  "Nigerian Civil War" = paste(
    "Focus on: which people led which side or organisation; which regions,",
    "states or cities were involved and on which side; which countries or",
    "bodies supported, supplied or mediated; and which events or operations",
    "happened at which places."
  ),

  "End SARS" = paste(
    "Focus on: which organisations or units were involved; which people or",
    "groups led or organised; which places protests or events occurred in;",
    "and which bodies investigated, responded or ruled."
  ),

  "Nigeria" = paste(
    "Focus on: which places lie inside or border which; which people held",
    "which office; which organisations the country belongs to; and which",
    "regions are associated with which industries or peoples."
  ),

  "2023 Nigerian general election" = paste(
    "Focus on: which candidate ran for which party; who won and who lost;",
    "who succeeded whom; which bodies organised or ruled on the election;",
    "and which candidate carried which states or regions."
  )
)

## A general instruction, used if the article is not listed above.
focus <- focus_by_article[[article$title]]
if (is.null(focus)) {
  focus <- paste("Focus on the people, places, organisations and events named,",
                 "and on how the text says they are connected.")
  message("No specific focus set for this article -- using the general one. ",
          "Add a case to focus_by_article for better results.")
}

## ---- Ask, passage by passage --------------------------------------------------
## ONE CALL OVER THE WHOLE ARTICLE RETURNS TOO LITTLE. A small model asked to
## read six thousand characters and summarise everything tends to return a
## handful of the most obvious relationships and stop. The resulting graph has
## five or six nodes, which looks thin beside the co-occurrence graph and
## understates what the method can do.
##
## Reading the article in passages works better. Each call sees less text, so it
## has less to compress, and the relationships it returns are more specific.
## The results are then combined and duplicates removed.
##
## Three or four passages is usually enough for a teaching graph. More passages
## means more calls, and each one takes time on a local model.

N_PASSAGES    <- 4      # how many pieces to read
PASSAGE_CHARS <- 3000   # characters per piece

passages <- {
  total <- min(nchar(article$text), N_PASSAGES * PASSAGE_CHARS)
  starts <- seq(1, total, by = PASSAGE_CHARS)
  vapply(starts, function(st) substr(article$text, st, st + PASSAGE_CHARS - 1),
         character(1))
}
passages <- passages[str_count(passages, "\\S+") > 80]   # ignore a short tail

cat("Reading", length(passages), "passages of about",
    PASSAGE_CHARS, "characters each.\n\n")

build_prompt <- function(passage) {
  paste0(
    "Read the passage below and list the named entities and the relationships ",
    "between them.\n\n",
    focus, "\n\n",
    "Rules:\n",
    "- Only include a relationship the passage states or clearly implies.\n",
    "- Keep each relation phrase to a few words.\n",
    "- Prefer specific entities (Enugu, Biafra, Yakubu Gowon) over general ",
    "ones (the region, the leader).\n",
    "- List every relationship you find, up to 12.\n",
    "- Do not add anything the passage does not support.\n\n",
    "PASSAGE:\n", passage
  )
}

cache_file <- file.path("cache", paste0("extraction_", article$slug, ".rds"))

extraction <- cache_or_run(cache_file, {

  chat <- chat_ollama(model = LLM_MODEL,
                      api_args = list(keep_alive = "10m"))

  ent_list <- list()
  rel_list <- list()

  for (i in seq_along(passages)) {
    cat("  passage", i, "of", length(passages), "... ")

    ## One failed passage should not lose the others.
    out <- tryCatch(
      chat$chat_structured(build_prompt(passages[i]), type = type_extraction),
      error = function(e) { cat("failed:", conditionMessage(e), "\n"); NULL }
    )
    if (is.null(out)) next

    n_e <- if (is.null(out$entities))  0 else nrow(out$entities)
    n_r <- if (is.null(out$relations)) 0 else nrow(out$relations)
    cat(n_e, "entities,", n_r, "relationships\n")

    if (n_e > 0) ent_list[[length(ent_list) + 1]] <- out$entities
    if (n_r > 0) rel_list[[length(rel_list) + 1]] <- out$relations
  }

  if (length(rel_list) == 0) {
    stop("No relationships returned from any passage. Nothing cached. ",
         "Try a smaller PASSAGE_CHARS, or a different model.")
  }

  ## Combine the passages and drop duplicates. The same relationship often
  ## appears in more than one passage, which is a sign it matters rather than a
  ## problem, but it should appear once in the graph.
  entities  <- bind_rows(ent_list) |>
    mutate(name = str_squish(name)) |>
    filter(nzchar(name)) |>
    distinct(name, .keep_all = TRUE)

  relations <- bind_rows(rel_list) |>
    mutate(across(c(subject, relation, object), str_squish)) |>
    filter(nzchar(subject), nzchar(object)) |>
    distinct(subject, object, .keep_all = TRUE)

  list(entities = entities, relations = relations)
})

saveRDS(extraction, "cache/extraction.rds")   # "the current one", read by 04

## ---- Look at what came back ---------------------------------------------------
cat("\n--- Entities ---\n");  print(extraction$entities)
cat("\n--- Relationships ---\n"); print(extraction$relations)
cat("\nEntities:", nrow(extraction$entities),
    "| Relationships:", nrow(extraction$relations), "\n")

## ---- Check the answers against the article -----------------------------------
## The schema guarantees the reply has the right SHAPE. It does not guarantee
## the reply is TRUE. A model can produce a statement that reads perfectly well
## and is not in the text.
##
## Read each row against the source. Do this on screen during the session: it is
## the habit that matters most, and it is the honest answer to "can we trust
## this?" -- you trust it because you checked it, not because it looks tidy.

cat("\n--- Article, for checking ---\n")
cat(substr(article$text, 1, 1200), "...\n")

## To drop rows you judge unsupported, note their numbers and un-comment:
# extraction$relations <- extraction$relations[-c(3, 7), ]
# saveRDS(extraction, cache_file)
# saveRDS(extraction, "cache/extraction.rds")

## ---- Running it again ---------------------------------------------------------
## The answer is cached, so editing the prompt above changes nothing until the
## cache is cleared. Delete the file, or pass refresh = TRUE to cache_or_run().

cat("\nNext: 04_llm_graph.R\n")
