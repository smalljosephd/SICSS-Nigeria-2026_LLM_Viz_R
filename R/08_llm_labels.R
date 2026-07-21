# =============================================================================
# 08_llm_labels.R  |  Let the model name the themes
# -----------------------------------------------------------------------------
# Script 07 leaves you with word lists. Turning "secur, peac, terror, conflict"
# into "Security and conflict" is ordinary work, and the model does it well.
#
# This is the language model working inside the topic-evolution chart rather
# than beside it: the chart's legend ends up in plain language instead of
# "Topic 1", "Topic 2".
#
# ONE THEME PER CALL. Asking for all themes at once means asking for a nested
# structure -- a list of records, each with two fields -- and smaller local
# models often return an empty list instead. Asking for a single label at a
# time keeps each request simple, and it works. It costs one call per theme,
# which is fine because the result is cached.
#
# RUN THIS and Cache -- it calls the model.
#
# Needs   :  cache/topic_fit.rds, Ollama running with the model pulled
# Produces:  cache/topic_labels.rds
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

fit <- readRDS("cache/topic_fit.rds")
K   <- ncol(fit$theta)

## ---- Collect the words for each theme ---------------------------------------
## The FREX words are used rather than the commonest words, because they
## separate one theme from another more sharply.
frex      <- labelTopics(fit, n = 10)$frex
top_words <- apply(frex, 1, paste, collapse = ", ")

## Check the input before spending time on model calls. If this is empty, the
## problem is in script 07, not here.
stopifnot(length(top_words) == K, all(nzchar(top_words)))

cat("--- Word lists going to the model ---\n")
for (i in seq_along(top_words)) {
  cat("Topic", i, ":", top_words[i], "\n")
}

## ---- Describe the answer we want --------------------------------------------
## A single field: one short label. Nothing nested, which is what makes this
## reliable on a small model.
type_label <- type_object(
  name = type_string("A short label of two to four words for this theme")
)

## ---- Ask, one theme at a time -----------------------------------------------
## The prompt mentions the words are stems. Without that, the model can be
## thrown by forms like "secur" and "econom".
label_one <- function(chat, words) {
  out <- chat$chat_structured(
    paste0("These word stems all come from one theme found in a set of ",
           "documents:\n\n", words, "\n\n",
           "Reply with a short label of two to four words describing what the ",
           "theme is about.",
           "The theme is for topic evolution chart based on President Trumps's tweet during his first presidency the Nigerian civil war Wikipedia article's revisions from 2005 to 2025",
           "The words are stems, so for instance, 'secur' means security and ",
           "'econom' means economic."),
    type = type_label
  )
  out$name
}

topic_labels <- cache_or_run("cache/topic_labels.rds", {
  
  ## keep_alive holds the model in memory between calls, so only the first one
  ## pays the loading cost
  chat <- chat_ollama(model = LLM_MODEL,
                      api_args = list(keep_alive = "10m"))
  
  names_vec <- character(K)
  for (i in seq_len(K)) {
    cat("Labelling topic", i, "of", K, "... ")
    names_vec[i] <- label_one(chat, top_words[i])
    cat(names_vec[i], "\n")
  }
  
  result <- list(labels = data.frame(topic = seq_len(K),
                                     name  = names_vec,
                                     stringsAsFactors = FALSE))
  
  ## Stop rather than cache a bad answer. Without this check, an empty or
  ## partial result gets saved and quietly reloaded on every later run.
  if (nrow(result$labels) != K || any(!nzchar(result$labels$name))) {
    stop("The model did not return a label for every theme. Nothing cached. ",
         "Try a smaller model, or write the labels by hand (see below).")
  }
  
  result
})

cat("\n--- Labels ---\n")
print(topic_labels$labels)

## ---- Check them -------------------------------------------------------------
## Read each label against its word list above. A label that does not fit its
## words should be rewritten. The model produces a first draft here, not a
## final answer, and saying so during the session is the honest framing.
##
## To correct one and save it:
# topic_labels$labels$name[3] <- "Trade and industry"
# saveRDS(topic_labels, "cache/topic_labels.rds")

## ---- Writing them all by hand -----------------------------------------------
## A perfectly good alternative, and often better -- you know the subject and
## the model does not. Read the word lists printed above, then:
#
# topic_labels <- list(labels = data.frame(
#   topic = 1:6,
#   name  = c("Independence and sovereignty",
#             "Economic development",
#             "Security and conflict",
#             "Regional cooperation",
#             "Climate and environment",
#             "Human rights"),
#   stringsAsFactors = FALSE
# ))
# saveRDS(topic_labels, "cache/topic_labels.rds")

## ---- Starting over ----------------------------------------------------------
## The answer is cached, so editing the prompt above changes nothing until the
## cache is cleared. Delete cache/topic_labels.rds, or pass refresh = TRUE to
## cache_or_run(), then run this script again.

cat("\nNext: 09_topic_evolution.R\n")
