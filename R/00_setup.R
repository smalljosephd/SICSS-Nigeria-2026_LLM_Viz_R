# =============================================================================
# 00_setup.R  |  Packages, paths, and folders
# -----------------------------------------------------------------------------
# Run this first, once per R session. Every other script starts by sourcing it.
# =============================================================================

## ---- Working directory ------------------------------------------------------
## All paths below are relative to the project folder (the one holding this
## R/ directory). Set it once, in whichever way suits you:
##
##   Easiest:  open SICSS_LLM_Viz_R.Rproj, and RStudio sets it for you.
##   Manual :  Session menu -> Set Working Directory -> Choose Directory...
##   In code:  edit and un-comment the line below.
# setwd("~/SICSS_LLM_Viz_R")

cat("Working directory:", getwd(), "\n")

## Warn early if we are pointed somewhere unexpected, rather than failing later
## with a confusing "file not found".
if (!dir.exists("R")) {
  warning("No R/ folder here. Set the working directory to the project folder.")
}

## ---- Folders ----------------------------------------------------------------
## data/     inputs you download or that ship with the project
## cache/    saved model output, so slow steps run only once
## prebuilt/ figures saved as images, used as a fallback during the session
## output/   anything exported for sharing

for (d in c("data", "cache", "prebuilt", "output")) {
  dir.create(d, showWarnings = FALSE)
}

## ---- Packages ---------------------------------------------------------------
pkgs <- c("tidytext", "widyr", "dplyr", "tidyr", "stringr",
          "readr", "tibble", "ggplot2", "scales", "quanteda",
          "quanteda.textstats", "igraph", "tidygraph", "ggraph",
          "stm", "ellmer", "httr2", "jsonlite", "patchwork"
)

## pacman installs whatever is missing and loads the whole list in one call.
if (!require("pacman", character.only = TRUE)) {
  install.packages("pacman", dep = TRUE)
  if (!require("pacman", character.only = TRUE))
    stop("Package not found")
}

## Load (installing first if needed) every package listed above.
p_load(pkgs, character.only = TRUE)
rm(pkgs)

## ---- Shared settings --------------------------------------------------------
## One seed for the whole project. Graph layouts and the 2-D reduction in
## script 06 are random; fixing the seed keeps figures identical.

SEED <- 2026

## The model we call through Ollama. Pull it once, in a terminal:
##   ollama pull llama3.2:3b
## A smaller model answers faster, which matters when the machine has no GPU.
## Swap to "llama3.1" if your machine is quick and you want better output.

#LLM_MODEL <- "llama3.1"
LLM_MODEL <- "llama3.2:3b"

## Which article the knowledge-graph scripts use.
##
## This is the SAME article the topic-evolution half uses, set in
## 06b_corpus_wikipedia.R. That is deliberate: one article runs through the
## whole session, asked a different question each time.
##   Part 1 asks: what does this article say, and how do the things it names
##                connect?
##   Part 2 asks: how has what it says changed, year by year?
##
## Other articles set up with their own extraction prompt in script 03:
##   "Nigeria"
##   "2023 Nigerian general election"
##   "End SARS"

ARTICLE_TITLE <- "Nigerian Civil War"

## A consistent look for every figure.
theme_set(theme_minimal(base_size = 12))
COL_DARK  <- "#1E3A5F"   # nodes, classical graph
COL_EDGE  <- "#5B8FB9"   # edges, classical graph
COL_LLM   <- "#B85042"   # nodes, LLM graph
COL_GREY  <- "#9AA0A6"   # edges, LLM graph

## Print sugegst message if all process are completed without error
cat("Setup complete. Seed:", SEED, "| Article:", ARTICLE_TITLE, "\n")