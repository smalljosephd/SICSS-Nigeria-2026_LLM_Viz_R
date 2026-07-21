# =============================================================================
# 09_topic_evolution.R  |  Draw the themes over time
# -----------------------------------------------------------------------------
# fit$theta holds, for every document, the share belonging to each theme. Every
# row adds up to 1: a 1975 speech might be 30 per cent one theme, 20 per cent
# another, and so on. Attaching the year to those shares and plotting them
# gives the picture of themes rising and falling.
#
# 
#
# Needs   :  cache/topic_fit.rds, cache/stm_input.rds,
#            cache/topic_labels.rds, cache/corpus.rds
# Produces:  prebuilt/04_topic_evolution.png
# =============================================================================

source("R/00_setup.R")
source("R/utils.R")

fit          <- readRDS("cache/topic_fit.rds")
stm_input    <- readRDS("cache/stm_input.rds")
cp           <- readRDS("cache/corpus.rds")

K <- ncol(fit$theta)          # how many themes the model fitted
cat("Themes in the model:", K, "\n")

## ---- Labels, with a fallback ------------------------------------------------
## Script 08 asks the model to name each theme. Small local models sometimes
## return nothing, so this checks the labels are usable before relying on them.
## If they are missing or incomplete, the chart falls back to "Topic 1",
##  "Topic 2" and still plots -- better than stopping mid-session.

labels_ok <- FALSE

if (file.exists("cache/topic_labels.rds")) {
  topic_labels <- readRDS("cache/topic_labels.rds")
  
  labels_ok <- !is.null(topic_labels$labels) &&
    nrow(topic_labels$labels) == K &&
    all(nzchar(topic_labels$labels$name))
}

if (labels_ok) {
  label_lookup <- setNames(topic_labels$labels$name,
                           paste0("T", topic_labels$labels$topic))
  cat("Using labels from the model:\n")
  print(topic_labels$labels)
} else {
  warning("Labels missing or incomplete -- using Topic 1..K instead. ",
          "Re-run 08_llm_labels.R, or write the labels by hand (see below).")
  label_lookup <- setNames(paste("Topic", seq_len(K)),
                           paste0("T", seq_len(K)))
}

## ---- Writing the labels by hand ---------------------------------------------
## Reading labelTopics(fit) and naming the themes yourself is a legitimate
## approach, and often a better one -- you know the subject matter and the
## model does not. To do that, un-comment and edit:
#
# label_lookup <- setNames(
#   c("Independence and sovereignty",   # T1
#     "Economic development",           # T2
#     "Security and conflict",          # T3
#     "Regional cooperation",           # T4
#     "Climate and environment",        # T5
#     "Human rights"),                  # T6
#   paste0("T", 1:6)
# )

## ---- Shares per document ----------------------------------------------------
theta <- as.data.frame(fit$theta)
colnames(theta) <- paste0("T", seq_len(K))
theta$Year <- stm_input$meta$Year

cat("\nShares table:", paste(dim(theta), collapse = " x "), "\n")
cat("Each row sums to 1. First three documents:\n")
print(head(round(theta, 3), 3))

## ---- Reshape ----------------------------------------------------------------
## ggplot draws one line per group, so the table needs one row per document per
## theme rather than one column per theme.
theta_long <- theta %>%
  pivot_longer(starts_with("T"), names_to = "topic", values_to = "share") %>%
  mutate(topic = recode(topic, !!!label_lookup))

## ---- Average within each time point -----------------------------------------
## When the corpus was split into chunks (the Wikipedia option), there are many
## documents per year. What we want on the chart is each YEAR's mixture, which
## is the average across that year's chunks.
##
## This also keeps the figure honest. A share is a proportion, so it must lie
## between 0 and 1. An average of proportions still lies between 0 and 1. A
## smoothing line fitted through scattered points does not: loess will happily
## draw a curve through minus twenty per cent, which is not a possible value.
theta_year <- theta_long %>%
  group_by(Year, topic) %>%
  summarise(share = mean(share), n_docs = n(), .groups = "drop")

cat("Time points:", n_distinct(theta_year$Year), "\n")
cat("Documents per time point:", min(theta_year$n_docs), "to",
    max(theta_year$n_docs), "\n")

## A quick check on whether the model found themes or just labelled documents.
## If most documents are almost entirely one theme, the model has separated the
## documents rather than finding anything shared between them.
dominant <- theta_long %>%
  group_by(Year) %>%
  summarise(top_share = max(share), .groups = "drop")
if (mean(dominant$top_share) > 0.85) {
  warning("Most documents are dominated by a single theme (mean top share ",
          round(mean(dominant$top_share), 2), "). The model is probably ",
          "separating documents rather than finding themes. ",
          "Use more, shorter documents: lower CHUNK_WORDS in 06b, or reduce K ",
          "in 07_topic_model.R.")
}

## ---- Plot -------------------------------------------------------------------
## Lines join the yearly averages. Points show the individual documents behind
## them, so the spread stays visible rather than hidden by the line.
##
## The y scale is fixed to 0 to 1 because that is the range a share can take.
## Nothing is being hidden: any curve leaving that range would be an artefact
## of the smoothing, not a feature of the text.
p_evolution <- ggplot(theta_year, aes(Year, share, colour = topic)) +
  geom_point(data = theta_long, aes(Year, share, colour = topic),
             alpha = 0.12, size = 0.9, show.legend = FALSE) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.8) +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  scale_colour_brewer(palette = "Dark2") +
  labs(title    = paste("Themes over time:", cp$label),
       subtitle = if (labels_ok)
         "Average share per time point. Names written by the model."
       else
         "Average share per time point.",
       x = NULL, y = "Share of text", colour = NULL) +
  theme(legend.position = "bottom")

print(p_evolution)
save_figure(p_evolution, "04_topic_evolution", width = 10, height = 6)

## ---- If you prefer a smoothed version ---------------------------------------
## A trend line reads more easily when there are many time points. Keep the
## limits, so a smoother that wanders outside 0 to 1 is clipped rather than
## drawn as though negative shares were possible.
#
# ggplot(theta_year, aes(Year, share, colour = topic)) +
#   geom_point(alpha = 0.4, size = 1.4) +
#   geom_smooth(method = "loess", span = 0.6, se = FALSE, linewidth = 1.1) +
#   coord_cartesian(ylim = c(0, 1)) +
#   scale_y_continuous(labels = percent_format(accuracy = 1))

## ---- Fewer lines, if the chart is crowded -----------------------------------
## Six lines can be hard to follow. Picking three makes the story clearer, and
## choosing which three is a decision worth naming out loud.
#
# keep <- label_lookup[c("T1", "T3", "T5")]
# theta_long %>%
#   filter(topic %in% keep) %>%
#   ggplot(aes(Year, share, colour = topic)) +
#   geom_point(alpha = 0.3, size = 1.3) +
#   geom_smooth(method = "loess", span = 0.5, se = FALSE, linewidth = 1.1) +
#   scale_y_continuous(labels = percent_format(accuracy = 1)) +
#   theme(legend.position = "bottom")

## ---- What the line is, and is not -------------------------------------------
## The line is smoothing. It shows the shape of a trend and nothing more, and
## how much it wiggles depends on the span setting -- try 0.3 and then 0.8 to
## see how much the picture moves. For a result you would report, estimateEffect
## fits the Year term properly and gives an interval around it:
#
# effects <- estimateEffect(1:6 ~ s(Year), fit, meta = stm_input$meta)
# plot(effects, "Year", method = "continuous", topics = 1, model = fit)

cat("\nSecond half complete.\n")