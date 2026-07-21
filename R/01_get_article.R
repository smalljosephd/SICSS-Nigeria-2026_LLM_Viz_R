# =============================================================================
# 01_get_article.R  |  Get one Wikipedia article and clean it
# -----------------------------------------------------------------------------
# Downloads the article named in 00_setup.R (ARTICLE_TITLE) and strips it down
# to plain prose.
#
# The saved file is named after the article, so switching ARTICLE_TITLE gives a
# separate cache rather than overwriting the previous one. Both can then sit
# side by side and you can move between them freely.
#
# Needs internet. If the download fails, the bundled sample article is used, so
# everything downstream still runs.
#
# Produces:  cache/article_<title>.rds  and  cache/article.rds
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

## ---- A short name for the file ----------------------------------------------
## "2023 Nigerian general election" becomes "2023_nigerian_general_election",
## which is safe to use in a filename.
slug <- tolower(gsub("[^A-Za-z0-9]+", "_", ARTICLE_TITLE))
slug <- gsub("^_|_$", "", slug)
cache_file <- file.path("cache", paste0("article_", slug, ".rds"))

## ---- Download ----------------------------------------------------------------
## tryCatch stops a failed download from ending the script. On a dry run with no
## connection, the bundled sample is used instead and work continues.
article_raw <- tryCatch({
  message("Fetching from Wikipedia: ", ARTICLE_TITLE)
  fetch_wikipedia(ARTICLE_TITLE)
}, error = function(e) {
  message("Download failed (", conditionMessage(e), ").")
  message("Using the bundled sample article instead.")
  paste(readLines("data/nigeria_sample_article.txt", warn = FALSE),
        collapse = " ")
})

article_source <- if (nchar(article_raw) > 5000) "wikipedia" else "sample"

## ---- Clean -------------------------------------------------------------------
article_txt <- clean_wiki(article_raw)

## A very short result usually means the title was misspelled, or a redirect
## did not resolve to the page you expected.
if (nchar(article_txt) < 500) {
  warning("Article is unexpectedly short (", nchar(article_txt), " characters). ",
          "Check the spelling of ARTICLE_TITLE in 00_setup.R.")
}

cat("\n--- Article ready ---\n")
cat("Title  :", ARTICLE_TITLE, "\n")
cat("Source :", article_source, "\n")
cat("Length :", nchar(article_txt), "characters\n")
cat("Opening:", substr(article_txt, 1, 200), "...\n\n")

## ---- Save --------------------------------------------------------------------
article <- list(title   = ARTICLE_TITLE,
                slug    = slug,
                text    = article_txt,
                n_chars = nchar(article_txt),
                source  = article_source)

saveRDS(article, cache_file)      # keyed by article, kept
saveRDS(article, "cache/article.rds")   # "the current one", read by 02 and 03

message("Saved: ", cache_file)
cat("\nNext: 02_cooccurrence_graph.R\n")
