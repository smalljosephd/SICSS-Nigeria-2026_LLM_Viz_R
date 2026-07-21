# LLM Visualisation in R

## SICSS-Nigeria 2026, Day 3 (Wednesday 22 July 2026)

## By Joseph David.

Two graphs, each built twice: first by counting words, then with a language
model doing the part counting cannot do.

| | Data | Counting gives you | The model adds |
|---|---|---|---|
| Knowledge graph | one Wikipedia article | words that share a sentence | what the things are, and how they relate |
| Themes over time | dated documents | numbered groups of word stems | a readable name for each theme |

---

## Start here

1. Open **`SICSS_LLM_Viz_R.Rproj`**. This sets the working directory, which is
   the most common thing to get wrong.
2. Run `source("R/00_setup.R")` — installs packages on the first run.
3. Install [Ollama](https://ollama.com) and pull a model:
   `ollama pull llama3.2:3b`
4. Run `source("run_all.R")` to build everything once.

---

## The scripts

Run in order the first time. After that each one stands alone — they read what
the earlier ones saved into `cache/`.

| Script | Does | Notes |
|---|---|---|
| `00_setup.R` | packages, folders, settings | sourced by all the others |
| `utils.R` | helper functions | definitions only |
| `01_get_article.R` | downloads one Wikipedia article | falls back to a bundled copy offline |
| `02_cooccurrence_graph.R` | graph from word counts | the counting method |
| `03_llm_extraction.R` | model reads the article | **calls the model — run beforehand** |
| `04_llm_graph.R` | draws the relationships | |
| `05_compare_graphs.R` | both graphs together | the comparison |
| `06a_check_snapshots.R` | tests whether an article changed enough to chart | **run this before choosing the Wikipedia corpus** |
| `06_load_corpus.R` | chooses which dated corpus to load | one setting at the top |
| `06b_corpus_wikipedia.R` | yearly snapshots of one article | needs a connection |
| `06c_corpus_tweets.R` | the bundled tweets | tested, no connection needed |
| `07_topic_model.R` | fits the topic model | **slow, run beforehand** |
| `08_llm_labels.R` | model names the themes | **calls the model — run beforehand** |
| `09_topic_evolution.R` | the themes chart | good to write live |

Anything marked "run beforehand" saves to `cache/`, so on the day it loads from
disk instantly.

---

## Choosing the text

**The article** (scripts 01–05). Set `ARTICLE_TITLE` in `00_setup.R`. Two are
set up with tailored prompts in script 03: `"Nigeria"` and
`"2023 Nigerian general election"`. Caches are named after the article, so both
can sit side by side.

**The dated documents** (scripts 06–09). Set `CORPUS` at the top of
`06_load_corpus.R`:

- `"trump"` — tweets, 2017–2021. Bundled. What the session uses.
- `"ungd"` — Nigeria at the UN, 1960 onwards. Needs a download from Harvard
  Dataverse; instructions are in the script.
- `"sotu"` — US State of the Union, 1790 onwards. One package to install.

After switching, delete `cache/topic_fit.rds` and `cache/topic_labels.rds` so
the model is fitted again for the new text.

---

## Documents

In `docs/`:

| File | For | What it covers |
|---|---|---|
| `Setup_Guide.docx` | participants | installing R, RStudio, packages, and Ollama, with a checklist |
| `Session_Handout.docx` | participants | a written version of the session, to read alongside or after |

---

## The session article

One article runs through the whole session, asked a different question in each
half:

- **Part 1** (scripts 01 to 05): what does this article say, and how do the
  things it names connect?
- **Part 2** (scripts 06 to 09): how has what it says changed, year by year?

It is set once, in `R/00_setup.R`:

```r
ARTICLE_TITLE <- "Nigerian Civil War"
```

Scripts 01, 03, 06a and 06b all read that setting, so changing it moves both
halves together. Four articles have a tailored extraction prompt in script 03:
`Nigerian Civil War`, `End SARS`, `Nigeria`, and
`2023 Nigerian general election`. Anything else falls back to a general prompt
and says so.

Caches are named after the article, so different articles sit side by side
rather than overwriting each other.

---

## Choosing the dated corpus

Set `CORPUS` at the top of `06_load_corpus.R`:

| Value | What it loads | Needs |
|---|---|---|
| `"tweets"` | 23,073 tweets as 49 monthly documents | nothing, bundled and tested |
| `"wikipedia"` | one article, one version per year | a connection, and a good verdict from `06a` |
| `"sotu"` | US State of the Union addresses | `remotes::install_github("quanteda/quanteda.corpora")` |

**Before choosing `"wikipedia"`, run `R/06a_check_snapshots.R`.** It pulls three
snapshots and reports whether the article grew and whether its vocabulary moved.
Wikipedia articles often grow by accretion, keeping old text and adding to it,
which leaves topic proportions flat and the chart dull. The check takes about a
minute and tells you before you spend an afternoon.

No Wikipedia account or API key is needed. Reading is open. Requests identify
themselves through a user-agent string, which the code sets.

After switching corpus, delete `cache/topic_fit.rds` and
`cache/topic_labels.rds` so the model is fitted again for the new text.

---

## Folders

```
R/          the scripts
docs/       four documents — see below
slides/     the deck
data/       inputs
cache/      saved results, so slow steps run once
prebuilt/   figures as PNG — keep these open during the session
output/     anything you export
```

Deleting a file in `cache/` makes the script that created it run again. That is
how you redo one step after changing a prompt or a setting.

---

## When something breaks

**`cannot open file 'R/00_setup.R'`** — wrong working directory. Open the
`.Rproj` file.

**Model call times out** — use a smaller model (`llama3.2:3b`) and send less
text.

**Extraction or labels come back empty** — small models struggle with nested
requests. Script 08 already asks for one label at a time; for extraction, lower
the item limit in the prompt.

**Changed a prompt but nothing changed** — the old answer is cached. Delete the
file in `cache/`.

**Graph is a tangle** — raise `MIN_EDGE` in `02_cooccurrence_graph.R`.

**`could not find function "convert"`** — use `quanteda::convert()`. Another
loaded package defines `convert` as well.
