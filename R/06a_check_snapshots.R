# =============================================================================
# 06a_check_snapshots.R  |  RUN THIS FIRST. Is the article worth using?
# -----------------------------------------------------------------------------
# Before spending time on twenty snapshots, check three.
#
# THE RISK THIS TESTS FOR. Wikipedia articles grow by accretion: new text is
# added, but old text usually stays. If that is what has happened, then a 2022
# snapshot is mostly the 2010 text with more bolted on, the proportions barely
# move, and the chart is six flat lines. That would be an honest result and a
# dull one to present.
#
# This script pulls three snapshots, spread across the years, and reports
# whether they differ enough to be worth modelling.
#
# WHAT TO LOOK FOR
#   Word counts     should grow substantially, e.g. 4,000 -> 15,000
#   Shared words    below about 0.60 means the vocabulary really moved
#   Distinctive     each year should show words the others do not
#
# No account or key is needed. The Wikipedia API is open for reading. It does
# ask that requests identify themselves, which fetch_revision_at() does.
#
# Produces: nothing. This only prints a report.
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

## ---- What to check ----------------------------------------------------------
## Set these, run, read the verdict at the bottom.
CHECK_TITLE <- ARTICLE_TITLE      # the session article, from 00_setup.R
CHECK_YEARS <- c(2006, 2014, 2022)

cat("\nChecking:", CHECK_TITLE, "\n")
cat("Years   :", paste(CHECK_YEARS, collapse = ", "), "\n\n")

## ---- Pull the three snapshots -----------------------------------------------
snaps <- list()

for (yr in CHECK_YEARS) {
  cat("Fetching", yr, "... ")

  rev <- tryCatch(
    fetch_revision_at(CHECK_TITLE, paste0(yr, "-06-01")),
    error = function(e) { cat("FAILED:", conditionMessage(e), "\n"); NULL }
  )

  if (is.null(rev)) {
    cat("no revision found. The article may not have existed yet.\n")
    next
  }

  clean <- clean_wikitext(rev$text)
  words <- str_extract_all(str_to_lower(clean), "[a-z]{4,}")[[1]]

  snaps[[as.character(yr)]] <- list(
    year      = yr,
    timestamp = rev$timestamp,
    raw_chars = nchar(rev$text),
    text      = clean,
    n_words   = length(words),
    words     = words,
    vocab     = unique(words)
  )

  cat("got revision of", substr(rev$timestamp, 1, 10),
      "|", format(length(words), big.mark = ","), "words\n")

  Sys.sleep(0.3)   # be a polite client; twenty requests is nothing, but still
}

if (length(snaps) < 2) {
  stop("Fewer than two snapshots retrieved. Check the article title spelling, ",
       "your internet connection, and whether the article existed in those years.")
}

## ---- Report 1: did the article grow? ----------------------------------------
cat("\n", strrep("-", 62), "\n", sep = "")
cat("SIZE\n")
cat(strrep("-", 62), "\n", sep = "")

sizes <- vapply(snaps, function(s) s$n_words, numeric(1))
for (nm in names(snaps)) {
  s <- snaps[[nm]]
  cat(sprintf("  %s   %8s words   (raw wikitext %s chars)\n",
              nm, format(s$n_words, big.mark = ","),
              format(s$raw_chars, big.mark = ",")))
}
growth <- max(sizes) / min(sizes)
cat(sprintf("\n  Largest is %.1f times the smallest.\n", growth))

## ---- Report 2: did the vocabulary move? -------------------------------------
## Jaccard similarity: shared words divided by total distinct words. Two
## identical documents give 1.0. Completely different ones give 0.
cat("\n", strrep("-", 62), "\n", sep = "")
cat("VOCABULARY OVERLAP\n")
cat(strrep("-", 62), "\n", sep = "")

nms <- names(snaps)
overlaps <- c()
for (i in seq_along(nms)) {
  for (j in seq_along(nms)) {
    if (j <= i) next
    a <- snaps[[nms[i]]]$vocab
    b <- snaps[[nms[j]]]$vocab
    jac <- length(intersect(a, b)) / length(union(a, b))
    overlaps <- c(overlaps, jac)
    cat(sprintf("  %s vs %s   %.2f shared\n", nms[i], nms[j], jac))
  }
}
mean_overlap <- mean(overlaps)

## ---- Report 3: what is distinctive about each year? -------------------------
## Words frequent in one snapshot and absent from the others. If the article
## really changed, these should read like different subject matter, not noise.
cat("\n", strrep("-", 62), "\n", sep = "")
cat("WORDS UNIQUE TO EACH YEAR\n")
cat(strrep("-", 62), "\n", sep = "")

common_words <- c("that", "this", "with", "from", "were", "which", "their",
                  "have", "been", "also", "after", "would", "into", "more",
                  "other", "when", "some", "such", "than", "them", "these")

for (nm in nms) {
  mine   <- snaps[[nm]]$words
  others <- unlist(lapply(setdiff(nms, nm), function(o) snaps[[o]]$vocab))
  only   <- mine[!(mine %in% others) & !(mine %in% common_words)]
  top    <- names(sort(table(only), decreasing = TRUE))[1:8]
  top    <- top[!is.na(top)]
  cat(sprintf("  %s:  %s\n", nm, paste(top, collapse = ", ")))
}

## ---- Verdict -----------------------------------------------------------------
cat("\n", strrep("=", 62), "\n", sep = "")
cat("VERDICT\n")
cat(strrep("=", 62), "\n", sep = "")

good_growth  <- growth >= 1.8
good_overlap <- mean_overlap <= 0.62

cat(sprintf("  Growth        %.1fx      %s\n", growth,
            if (good_growth) "good" else "weak"))
cat(sprintf("  Mean overlap  %.2f      %s\n", mean_overlap,
            if (good_overlap) "good" else "high"))

cat("\n")
if (good_growth && good_overlap) {
  cat("  The article changed substantially. Go ahead with the full run:\n")
  cat("  set CORPUS <- \"wikipedia\" in 06_load_corpus.R and run it.\n")
} else if (good_growth || good_overlap) {
  cat("  Borderline. The article changed, but not dramatically. The chart may\n")
  cat("  show gentle drift rather than clear movement. Either try another\n")
  cat("  article, or accept a quieter chart, or use the tweet corpus instead.\n")
} else {
  cat("  The snapshots are too similar. A themes-over-time chart would be\n")
  cat("  close to flat. Use the tweet corpus instead:\n")
  cat("  set CORPUS <- \"tweets\" in 06_load_corpus.R.\n")
}
cat(strrep("=", 62), "\n\n", sep = "")

## Other articles worth trying if this one is weak. Longer-running and more
## heavily revised articles tend to move more.
##   "History of Nigeria"
##   "Economy of Nigeria"
##   "Boko Haram"
##   "End SARS"                (shorter series, from 2020)
