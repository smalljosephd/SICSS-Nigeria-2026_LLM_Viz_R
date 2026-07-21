# =============================================================================
# 07_topic_model.R  |  Fit the topic model
# -----------------------------------------------------------------------------
# A topic model looks at which words appear together across documents and
# groups them into themes. Nobody supplies the themes -- the model works them
# out from the text alone.
#
# The version used here (stm) allows a theme's share to change with a document
# variable. Setting prevalence = ~ s(Year) lets each theme rise and fall over
# time, which is what makes the chart in script 09 possible.
#
# RUN THIS BEFORE THE SESSION. Fitting takes a minute or two; the result is
# cached, so the session-day run loads it instantly.
#
# Needs   :  cache/corpus.rds  (from 06_load_corpus.R)
# Produces:  cache/topic_fit.rds, cache/stm_input.rds
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

cp   <- readRDS("cache/corpus.rds")
corp <- cp$corpus

cat("Corpus:", cp$label, "|", ndoc(corp), "documents\n")

## ---- Prepare the word counts ------------------------------------------------
## The model needs a table of documents by words, with counts in the cells.
##
##   tokens_wordstem  treats "govern", "government" and "governing" as one word
##   dfm_trim         drops very rare words, which add noise and slow the fit
dfm_topic <- corp |>
  tokens(remove_punct = TRUE, remove_numbers = TRUE, remove_symbols = TRUE) |>
  tokens_tolower() |>
  tokens_remove(c(stopwords("en"), cp$extra_stop)) |>
  tokens_wordstem() |>
  dfm() |>
  dfm_trim(min_termfreq = 5, min_docfreq = 3)

cat("Documents x words:", paste(dim(dfm_topic), collapse = " x "), "\n")

## The 15 commonest words, as a sanity check. If procedural words still lead
## the list, add them to EXTRA_STOP in 06_load_corpus.R and run this again.
print(topfeatures(dfm_topic, 15))

## Convert to the shape stm expects. The Year variable travels with it, in
## stm_input$meta, which is how the model can use time.
## quanteda:: prefix avoids a clash with other packages that define convert()
stm_input <- quanteda::convert(dfm_topic, to = "stm")
saveRDS(stm_input, "cache/stm_input.rds")

## ---- Fit --------------------------------------------------------------------
## K is the number of themes to look for, and it is your choice, not something
## the data settles. Fewer themes give a broader picture; more themes split it
## finer. Fitting at two values and comparing is worth doing, and worth showing.
## As a rough guide, you want many more documents than themes. With a few
## hundred documents, six to ten themes is comfortable. With only twenty or
## thirty, the model tends to give each document its own theme, and the chart
## then shows which document is which rather than what they share. If that
## happens, use more and shorter documents rather than fewer themes.
K_TOPICS <- 6

cat("Documents:", ndoc(corp), "| Themes requested:", K_TOPICS, "\n")
if (ndoc(corp) < K_TOPICS * 10) {
  warning("Only ", ndoc(corp), " documents for ", K_TOPICS, " themes. ",
          "The model may separate documents rather than find themes. ",
          "Consider splitting the text into smaller pieces (see CHUNK_WORDS ",
          "in 06b_corpus_wikipedia.R).")
}

fit <- cache_or_run("cache/topic_fit.rds", {
  stm(documents  = stm_input$documents,
      vocab      = stm_input$vocab,
      K          = K_TOPICS,
      prevalence = ~ s(Year),    # lets each theme's share vary with Year
      data       = stm_input$meta,
      max.em.its = 75,
      init.type  = "Spectral",   # a repeatable starting point
      seed       = SEED,
      verbose    = FALSE)
})

## ---- Read the themes --------------------------------------------------------
## Each theme comes back as a list of words. Two lists are printed:
##
##   Highest Prob  the commonest words in the theme
##   FREX          words common in this theme and rare in the others, which
##                 usually describes the theme better
##
## Reading these and deciding what each theme is about is the traditional next
## step. Script 08 hands that job to the language model.
labelTopics(fit, n = 8)

cat("\nThemes fitted:", K_TOPICS, "\n")
cat("To try a different number, change K_TOPICS above, delete\n")
cat("cache/topic_fit.rds, and run this script again.\n")
cat("\nNext: 08_llm_labels.R\n")
