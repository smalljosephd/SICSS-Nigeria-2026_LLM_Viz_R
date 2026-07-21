# =============================================================================
# 04_llm_graph.R  |  Draw the model's relations as a knowledge graph
# -----------------------------------------------------------------------------
# Each relation becomes an arrow: subject -> object, labelled with the relation.
# Unlike script 02, these links have a direction and a name.
#
# Needs   :  cache/extraction.rds  (from 03_llm_extraction.R)
# Produces:  cache/llm_graph.rds, prebuilt/02_llm_graph.png
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

extraction <- readRDS("cache/extraction.rds")
article    <- readRDS("cache/article.rds")

cat("Relations to draw:", nrow(extraction$relations), "\n")

## ---- Build the graph --------------------------------------------------------
## build_relation_graph() is in utils.R. It puts subject and object in the first
## two columns before building the graph, because graph_from_data_frame() reads
## whatever sits in those positions as the two ends of each edge. Renaming the
## columns without reordering them produces a graph built on the wrong pair --
## an error with no warning attached.
llm_graph <- build_relation_graph(extraction$relations)

cat("Graph:", gorder(llm_graph), "entities,", gsize(llm_graph), "relations\n")

## ---- Draw -------------------------------------------------------------------
set.seed(SEED)

p_llm <- ggraph(llm_graph, layout = "fr") +
  geom_edge_link(
    aes(label = relation),
    arrow       = grid::arrow(length = grid::unit(3, "mm"), type = "closed"),
    end_cap     = ggraph::circle(5, "mm"),   # stop the arrow before the point
    angle_calc  = "along",                   # label follows the line
    label_dodge = grid::unit(2.5, "mm"),
    colour      = COL_GREY,
    label_size  = 2.8
  ) +
  geom_node_point(size = 8, colour = COL_LLM) +
  geom_node_text(aes(label = name), repel = TRUE, size = 3.2,
                 max.overlaps = 20) +
  theme_graph(base_family = "sans") +
  labs(title    = paste0("Knowledge graph: \u201C", article$title, "\u201D"),
       subtitle = "Relations read from the article by the model. Directed and labelled.")

print(p_llm)

## ---- Save -------------------------------------------------------------------
saveRDS(list(graph = llm_graph, plot = p_llm), "cache/llm_graph.rds")
save_figure(p_llm, "02_llm_graph")

## ---- Where this leads -------------------------------------------------------
## This is one article, drawn as one picture. The same extraction step, run
## across hundreds of documents and stored in a graph database, is what tools
## such as Neo4j GraphRAG do -- the graph is then queried rather than viewed
## ("how is X connected to Y?"). The step you have just run is the core of it.

cat("\nNext: 05_compare_graphs.R puts the two graphs side by side.\n")
