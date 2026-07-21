# =============================================================================
# 05_compare_graphs.R  |  The two methods, side by side
# -----------------------------------------------------------------------------
# Both graphs come from the SAME article. Only the method differs, so the
# comparison is a fair one -- this is the point of the whole first half.
#
#   Left  (script 02): counting. Words that share a sentence are joined.
#   Right (script 04): reading.  The model states how the entities relate.
#
# Needs   :  cache/cooccurrence_graph.rds, cache/llm_graph.rds
# Produces:  prebuilt/03_comparison.png
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

co  <- readRDS("cache/cooccurrence_graph.rds")
llm <- readRDS("cache/llm_graph.rds")
article <- readRDS("cache/article.rds")

## ---- Put them together ------------------------------------------------------
## patchwork joins two ggplot objects with the + operator.
p_left  <- co$plot  + labs(title = "Counting words", subtitle = NULL)
p_right <- llm$plot + labs(title = "Reading the text", subtitle = NULL)

p_compare <- (p_left | p_right) +
  plot_annotation(
    title    = paste0("Same article, two methods: \u201C", article$title, "\u201D"),
    subtitle = paste("Left: words joined when they share a sentence.",
                     "Right: relations the model read from the text."),
    theme    = theme(plot.title    = element_text(face = "bold", size = 15),
                     plot.subtitle = element_text(size = 11))
  )

print(p_compare)
save_figure(p_compare, "03_comparison", width = 14, height = 6)

## ---- What the picture shows -------------------------------------------------
## Worth stating plainly while both are on screen:
##
##  - The left graph tells you which words keep company. It cannot tell you
##    what connects them: "nigeria" and "lagos" are linked, and that is all.
##
##  - The right graph names the connection and gives it a direction:
##    Lagos -> is the largest city in -> Nigeria.
##
##  - The right graph has fewer points. It keeps entities, not every frequent
##    word, so it is smaller and carries more meaning per link.
##
##  - The left graph is arithmetic: run it again and you get the same numbers.
##    The right graph is a reading, and readings can be wrong -- which is why
##    script 03 ends by checking each relation against the article.

cat("\n--- Summary ---\n")
cat("Co-occurrence :", gorder(co$graph),  "words,   ", gsize(co$graph),  "links\n")
cat("Model         :", gorder(llm$graph), "entities,", gsize(llm$graph), "relations\n")

cat("\nFirst half complete. Next: 06_topic_evolution.R\n")
