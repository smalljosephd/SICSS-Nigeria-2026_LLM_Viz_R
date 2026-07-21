# =============================================================================
# 02_cooccurrence_graph.R  |  Classical method: word co-occurrence
# -----------------------------------------------------------------------------
# The "before" picture. Words become points; two words are joined when they
# appear in the same sentence. This is the traditional way to turn a document
# into a network, and it needs no language model at all.
#
# What it shows : which words tend to appear together
# What it misses: how they are related. It can link "Lagos" and "Nigeria"
#                 but cannot say that Lagos is a city IN Nigeria.
# That gap is what script 03 fills.
#
# Needs   :  cache/article.rds   (from 01_get_article.R)
# Produces:  cache/cooccurrence_graph.rds, prebuilt/01_cooccurrence.png
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

article <- readRDS("cache/article.rds")
cat("Article:", article$title, "|", article$n_chars, "characters\n")

## ---- Count word pairs -------------------------------------------------------
## Each sentence is treated as a small document, so words sharing a sentence
## are counted as co-occurring. top_n keeps only the most frequent words --
## without it the graph becomes an unreadable tangle.
## Words that survive the standard stop-word list but carry no subject matter.
## "also" and "made" appeared as well-connected nodes in an early run, which is
## a good illustration of why this list is never finished.
FILLER <- c("also", "made", "would", "could", "one", "two", "many", "however",
            "later", "following", "including", "although", "became", "well")

co_pairs <- sentence_cooccurrence(article$text, top_n = 32, min_chars = 4) |>
  filter(!(item1 %in% FILLER), !(item2 %in% FILLER))

cat("Word pairs found:", nrow(co_pairs), "\n")
print(head(co_pairs, 8))

## ---- Build the graph --------------------------------------------------------
## MIN_EDGE is the knob to turn during the session. Raising it drops the weaker
## links and clears the picture. Show this live: the text has not changed, only
## the threshold has. Where to draw that line is the analyst's decision, and
## making it visible is part of the lesson.
MIN_EDGE <- 1        # try 1, then 2, then 3

co_graph <- co_pairs |>
  filter(n >= MIN_EDGE) |>
  graph_from_data_frame(directed = FALSE) |>
  as_tbl_graph() |>
  mutate(degree = centrality_degree())

cat("Graph:", gorder(co_graph), "words,", gsize(co_graph), "links\n")

## The best-connected words, which are usually the article's main subjects
co_graph |>
  as_tibble() |>
  arrange(desc(degree)) |>
  slice_head(n = 5) |>
  print()

## ---- Draw -------------------------------------------------------------------
## Layout "fr" spreads the points so connected words sit near each other. It
## starts from random positions, so the seed keeps the picture the same each run.
set.seed(SEED)

p_cooccurrence <- ggraph(co_graph, layout = "fr") +
  geom_edge_link(aes(width = n), alpha = 0.5,
                 colour = COL_EDGE, show.legend = FALSE) +
  geom_node_point(aes(size = degree), colour = COL_DARK) +
  geom_node_text(aes(label = name), repel = TRUE, size = 3.2,
                 max.overlaps = 20) +
  scale_edge_width(range = c(0.3, 2.2)) +
  scale_size(range = c(2, 9)) +
  theme_graph(base_family = "sans") +
  labs(title    = paste0("Word co-occurrence: \u201C", article$title, "\u201D"),
       subtitle = "Words joined when they share a sentence. No direction, no labels.")

print(p_cooccurrence)

## ---- Save -------------------------------------------------------------------
saveRDS(list(graph = co_graph, pairs = co_pairs, plot = p_cooccurrence),
        "cache/cooccurrence_graph.rds")
save_figure(p_cooccurrence, "01_cooccurrence")

cat("\nNext: 03_llm_extraction.R asks the model to read the same article\n")
cat("and return the relationships this method cannot see.\n")
