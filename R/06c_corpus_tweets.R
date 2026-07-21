# =============================================================================
# 06c_corpus_tweets.R  |  Fallback corpus: tweets, 2017 to 2021
# -----------------------------------------------------------------------------
# THE TESTED PATH. This data ships with the project and this loader has been
# checked against the real file: 23,073 tweets reduce to 49 monthly documents
# covering January 2017 to January 2021.
#
# Use it if the Wikipedia snapshots do not work out, or if you would rather not
# depend on a live connection during the session. Everything after this script
# is identical either way.
#
# Source: github.com/MarkHershey/CompleteTrumpTweetsArchive
# Columns: ID, Time, Tweet URL, Tweet Text
#
# TWO THINGS WORTH POINTING AT WHILE THIS RUNS
#
# 1. The header row has leading spaces, so the names arrive as " ID" rather
#    than "ID". Trimming the names fixes it. Small, and it stops the script
#    dead if missed. Real data is often like this.
#
# 2. A single tweet is too short to model. A topic model works by seeing which
#    words keep company across a document, and a tweet has too few words for
#    that to mean anything. So all tweets from one month are joined into one
#    document. The same move applies to any short text: survey answers, chat
#    messages, comment threads.
#
# Sourced by 06_load_corpus.R. Can also be run on its own.
# =============================================================================

if (!exists("SEED")) source("R/00_setup.R")
if (!exists("cache_or_run")) source("R/utils.R")

csv_path <- "data/trump_tweets_in_office.csv"

if (!file.exists(csv_path)) {
  stop("Missing ", csv_path, "\n",
       "Download from github.com/MarkHershey/CompleteTrumpTweetsArchive ",
       "and save it into data/")
}

## ---- Read and tidy ------------------------------------------------------------
raw <- read_csv(csv_path, show_col_types = FALSE)
names(raw) <- str_trim(names(raw))        # see note 1 above

tweets <- raw |>
  rename(id = ID, time = Time, url = `Tweet URL`, text = `Tweet Text`) |>
  mutate(
    time  = as.POSIXct(time, format = "%Y-%m-%d %H:%M", tz = "UTC"),
    month = format(time, "%Y-%m")
  ) |>
  filter(!is.na(time), !is.na(text)) |>
  mutate(
    text = str_remove_all(text, "https?://\\S+"),   # links carry no theme
    text = str_remove_all(text, "@\\w+"),           # usernames likewise
    text = str_remove(text, "^RT\\s*:?\\s*")        # retweet marker
  )

cat("Tweets loaded:", format(nrow(tweets), big.mark = ","), "\n")

## ---- Monthly documents --------------------------------------------------------
corpus_df <- tweets |>
  group_by(month) |>
  summarise(text = paste(text, collapse = " "),
            n_tweets = n(), .groups = "drop") |>
  mutate(
    ## Year as a decimal so months sit in order along the x-axis.
    ## March 2018 becomes 2018.17, and the chart reads left to right.
    Year = as.integer(substr(month, 1, 4)) +
           (as.integer(substr(month, 6, 7)) - 1) / 12
  ) |>
  select(Year, text, n_tweets)

cat("Monthly documents:", nrow(corpus_df), "\n")
cat("Covering:", format(min(corpus_df$Year), nsmall = 2), "to",
    format(max(corpus_df$Year), nsmall = 2), "\n")

EXTRA_STOP   <- c("amp", "rt", "will", "great", "just", "get", "president")
CORPUS_LABEL <- "Tweets, 2017 to 2021"
CORPUS_WHICH <- "tweets"
