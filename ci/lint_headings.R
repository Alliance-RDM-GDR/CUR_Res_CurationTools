#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# ci/lint_headings.R
# Checks Markdown headings (##, ###, ####) in the book's .qmd files for:
#   1. Title Case on the English portion of each heading.
#   2. Stray leading numbering (e.g. "## 1. Overview").
#   3. Duplicate headings within the same file.
#   4. Malformed "#" markers (missing space, double space).
#   5. Bilingual headings ("English // French") where the French half was
#      left untranslated (identical to the English half).
#
# This does NOT touch the French half's casing: French headings use sentence
# case ("Charger les bibliothèques"), not Title Case, so only the text before
# " // " is checked for Title Case.
#
# Exit status 0 = clean, 1 = problems found (fails CI).
# ------------------------------------------------------------------------------

qmd_files <- list.files(pattern = "_Notebook\\.qmd$")

if (length(qmd_files) == 0) {
  cat("No *_Notebook.qmd files found — nothing to lint.\n")
  quit(status = 0)
}

# Words that stay lowercase in Title Case unless they're the first word.
minor_words <- c(
  "a", "an", "the", "and", "or", "nor", "for", "of", "in", "on", "to",
  "with", "using", "via", "vs", "at", "by", "from", "into", "onto"
)

is_title_case_word <- function(word, position) {
  # Code spans ("`magick`") and parenthetical annotations ("(summary)",
  # "(st_layers)") are exempt entirely — they're identifiers, not prose.
  if (grepl("[`()]", word)) return(TRUE)
  core <- gsub("[^A-Za-z0-9]", "", word)
  if (core == "") return(TRUE) # pure punctuation
  if (grepl("^[A-Z0-9]+$", core)) return(TRUE) # acronym (JSON, PDF, R...)
  if (position > 1 && tolower(core) %in% minor_words) return(TRUE)
  substr(core, 1, 1) == toupper(substr(core, 1, 1))
}

check_title_case <- function(heading_en) {
  # Ignore inline code spans and their contents for word-splitting purposes,
  # but keep parens/backticks so strip_code_refs can still exempt them.
  words <- strsplit(trimws(heading_en), "\\s+")[[1]]
  if (length(words) == 0) return(TRUE)
  all(vapply(seq_along(words), function(i) is_title_case_word(words[i], i), logical(1)))
}

problems <- list()

add_problem <- function(file, line_no, message) {
  problems[[length(problems) + 1]] <<- sprintf("%s:%d: %s", file, line_no, message)
}

for (f in qmd_files) {
  lines <- readLines(f, warn = FALSE)
  heading_idx <- grep("^#{2,4}[[:space:]]", lines)
  seen_headings <- character(0)

  for (idx in heading_idx) {
    raw <- lines[idx]

    # Malformed marker: "##Text" (no space) already excluded by the regex
    # above (requires a space after the #s). Catch a double space instead.
    if (grepl("^#{2,4}  ", raw)) {
      add_problem(f, idx, sprintf('double space after heading marker: "%s"', raw))
    }

    hashes <- regmatches(raw, regexpr("^#{2,4}", raw))
    text <- trimws(sub("^#{2,4}[[:space:]]+", "", raw))

    # Stray leading numbering, e.g. "1. Overview" or "5. Curation Insights"
    if (grepl("^[0-9]+\\.[[:space:]]", text)) {
      add_problem(f, idx, sprintf('stray numbering in heading: "%s"', text))
    }

    # Split bilingual "English // French" headings
    parts <- strsplit(text, "[[:space:]]//[[:space:]]")[[1]]
    heading_en <- parts[1]
    heading_fr <- if (length(parts) > 1) parts[2] else NA_character_

    if (!check_title_case(heading_en)) {
      add_problem(f, idx, sprintf('not Title Case: "%s"', heading_en))
    }

    if (!is.na(heading_fr) && identical(trimws(heading_fr), trimws(heading_en))) {
      add_problem(f, idx, sprintf('French half looks untranslated: "%s"', text))
    }

    # Duplicate heading text within the same file (same level + text)
    key <- paste0(hashes, "|", text)
    if (key %in% seen_headings) {
      add_problem(f, idx, sprintf('duplicate heading in this file: "%s"', text))
    }
    seen_headings <- c(seen_headings, key)
  }
}

if (length(problems) > 0) {
  cat("Heading style problems found:\n\n")
  cat(paste(" -", unlist(problems)), sep = "\n")
  cat(sprintf("\n\n%d problem(s) across %d file(s).\n", length(problems), length(qmd_files)))
  quit(status = 1)
} else {
  cat(sprintf("All headings in %d notebook(s) are clean.\n", length(qmd_files)))
  quit(status = 0)
}
