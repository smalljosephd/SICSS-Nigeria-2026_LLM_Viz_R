# =============================================================================
# 06_load_corpus.R  |  Choose and load a dated corpus
# -----------------------------------------------------------------------------
# The chart in script 09 shows how themes change over time, so every document
# needs a date. The Wikipedia article from script 01 has none, which is why the
# second half of the session loads different data.
#
# This script only chooses. The actual loading is in one of three files, so
# that a problem in one cannot affect the others:
#
#   "wikipedia"   06b_corpus_wikipedia.R   yearly snapshots of one article
#   "tweets"      06c_corpus_tweets.R      the tested fallback, bundled
#   "sotu"        built in below           US State of the Union addresses
#
# Everything after this script is identical whichever you choose. That is worth
# saying in the session: the method does not care what the text is, only that
# each document carries a date.
#
# BEFORE CHOOSING "wikipedia": run 06a_check_snapshots.R. It pulls three
# snapshots and tells you whether the article changed enough to be worth it.
#
# Produces: cache/corpus.rds
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

## ---- Choose --------------------------------------------------------------
## "wikipedia"  the one-article thread. Needs a connection, and needs
##              06a_check_snapshots.R to have given a good verdict.
## "tweets"     tested, bundled, no connection needed. The safe choice.
## "sotu"       needs one extra package installed from GitHub.
CORPUS <- "wikipedia"
#CORPUS <- "tweets"

# ---------------------------------------------------------------------------
if (CORPUS == "wikipedia") {

  source("R/06b_corpus_wikipedia.R")

} else if (CORPUS == "tweets") {

  source("R/06c_corpus_tweets.R")

} else if (CORPUS == "sotu") {

  ## US State of the Union addresses, 1790 onwards. About 240 dated documents,
  ## so the trend lines come out smoother than with either option above.
  ## Install once:  remotes::install_github("quanteda/quanteda.corpora")
  if (!requireNamespace("quanteda.corpora", quietly = TRUE)) {
    stop("Package quanteda.corpora is not installed. Run:\n",
         '  remotes::install_github("quanteda/quanteda.corpora")')
  }

  corp_sotu <- quanteda.corpora::data_corpus_sotu
  corpus_df <- tibble(
    text = as.character(corp_sotu),
    Year = as.integer(format(quanteda::docvars(corp_sotu, "Date"), "%Y"))
  ) |> filter(!is.na(Year))

  cat("Addresses loaded:", nrow(corpus_df), "\n")
  EXTRA_STOP   <- c("congress", "government", "president", "united", "states",
                    "american", "america", "year", "years")
  CORPUS_LABEL <- "US State of the Union addresses, 1790 to present"
  CORPUS_WHICH <- "sotu"

} else {
  stop("CORPUS must be \"wikipedia\", \"tweets\", or \"sotu\". Got: ", CORPUS)
}


# ---------------------------------------------------------------------------
# Build the corpus object
# ---------------------------------------------------------------------------
if (!exists("corpus_df")) stop("No corpus_df was produced. Check the loader above.")

corp <- quanteda::corpus(corpus_df, text_field = "text")
quanteda::docvars(corp, "Year") <- corpus_df$Year

cat("\nCorpus ready:", quanteda::ndoc(corp), "documents\n")
cat("Label       :", CORPUS_LABEL, "\n")

saveRDS(list(corpus     = corp,
             extra_stop = EXTRA_STOP,
             label      = CORPUS_LABEL,
             which      = CORPUS_WHICH),
        "cache/corpus.rds")

message("Saved: cache/corpus.rds")

## Switching corpus later: change CORPUS above, then delete cache/topic_fit.rds
## and cache/topic_labels.rds so the model is fitted again for the new text.
## Without that, scripts 07 to 09 load results belonging to the previous corpus
## and the chart will not match the data.

cat("\nNext: 07_topic_model.R\n")
