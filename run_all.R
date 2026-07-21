# =============================================================================
# run_all.R  |  Run the whole project from start to finish
# -----------------------------------------------------------------------------
# Useful for the rehearsal run and for rebuilding everything after a change.
# Run the numbered scripts one at a time instead, so a
# problem in one step does not take the rest down with it.
#
# The steps that call the model or fit the topic model cache their results, so
# running this a second time is quick.
# =============================================================================

## Order matters: each script uses what the ones before it saved.
##
## NOT included here: R/06a_check_snapshots.R. That one is a probe, not a step.
## Run it on its own before choosing the Wikipedia corpus in 06_load_corpus.R.
scripts <- c(
  "R/01_get_article.R",        # download and clean one Wikipedia article
  "R/02_cooccurrence_graph.R", # classical graph from word counts
  "R/03_llm_extraction.R",     # model reads the article  [calls the model]
  "R/04_llm_graph.R",          # draw the model's relations
  "R/05_compare_graphs.R",     # the two graphs side by side
  "R/06_load_corpus.R",        # load a dated corpus (see 06a first)
  "R/07_topic_model.R",        # fit the topic model      [slow, cached]
  "R/08_llm_labels.R",         # model names the themes   [calls the model]
  "R/09_topic_evolution.R"     # draw themes over time
)

for (s in scripts) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("RUNNING: ", s, "\n", sep = "")
  cat(strrep("=", 70), "\n", sep = "")

  ## try() keeps one failure from stopping the rest, so a single run tells you
  ## everything that is broken instead of only the first thing.
  result <- try(source(s, echo = FALSE), silent = FALSE)

  if (inherits(result, "try-error")) {
    cat("\n*** FAILED: ", s, "\n", sep = "")
    cat("*** Open that script and run it line by line to see why.\n")
  }
}

cat("\n", strrep("=", 70), "\n", sep = "")
cat("Finished. Figures are in prebuilt/\n")
print(list.files("prebuilt", pattern = "\\.png$"))
