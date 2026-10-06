#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_ReadmeFileList_Script.R
# Purpose: Diff the file list documented in a README.txt against the files
#          actually present in the dataset directory. Catches missing
#          extensions, name typos, undocumented files, and orphaned entries —
#          the kind of README/disk mismatch that is easy to miss on a manual
#          read but trivial to check computationally.
# Assumes: a README following the common DMP/data-curation template, with
#          file entries on lines of the form "Filename: <name>" (case-
#          insensitive, optional letter/number prefix, colon spacing varies).
#          If no such lines are found, the script says so rather than
#          guessing at a different format.
# Usage:   Rscript Inspect_ReadmeFileList_Script.R <target_directory> [output_dir] [readme_filename]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Dataset Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_ReadmeFileList")
  readme_name <- "README.txt"
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_ReadmeFileList_Script.R /path/to/dataset [output_dir] [readme_filename]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_ReadmeFileList")
  readme_name <- if (length(args) >= 3) args[3] else "README.txt"
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# 2. Locate README ---------------------------------------------------------------
readme_matches <- list.files(target_dir, pattern = paste0("^", readme_name, "$"),
                              recursive = TRUE, full.names = TRUE, ignore.case = TRUE)

if (length(readme_matches) == 0) {
  message(sprintf("No file named '%s' found under %s. Exiting.", readme_name, target_dir))
  quit(status = 0)
}
# A submission can contain several files with README-like names (e.g. a note
# inside a participant subfolder). The dataset's own README is the shallowest one.
readme_depth <- lengths(regmatches(readme_matches, gregexpr("[/\\\\]", readme_matches)))
readme_path <- readme_matches[which.min(readme_depth)]
message(paste("Using README:", readme_path))

# 3. Extract README file-list entries --------------------------------------------
readme_lines <- readLines(readme_path, warn = FALSE)

# Matches lines like "A. Filename: foo.csv" or "Filename:foo" (colon spacing varies)
# Recognizes the English DMP template ("Filename:") and the French-Canadian
# equivalent ("Nom de fichier :"), since FRDR receives submissions in both.
entry_pattern <- "(?i)(?:filename|nom de fichier)\\s*:\\s*(.+?)\\s*$"
entry_lines <- readme_lines[str_detect(readme_lines, entry_pattern)]

readme_entries <- str_match(entry_lines, entry_pattern)[, 2] %>%
  str_trim() %>%
  discard(~ .x == "")

if (length(readme_entries) == 0) {
  message("No 'Filename:' style entries found in the README. This script only recognizes that template pattern — skipping the diff.")
  quit(status = 0)
}

message(sprintf("Found %d file-list entries in the README.", length(readme_entries)))

# 4. Inventory actual files (excluding the README and our own curation outputs) --
# "Curation_Results" is this project's standing convention for where a dataset's
# own inspection reports get moved (see CURATION_GUIDELINES.md) — it must be
# excluded here, or a report generated on a prior pass gets diffed against the
# README as if it were depositor content.
disk_files <- list.files(target_dir, recursive = TRUE, full.names = FALSE, all.files = FALSE)
disk_files <- disk_files[!str_detect(basename(disk_files), paste0("^", readme_name, "$"))]
disk_files <- disk_files[!str_detect(disk_files, "(?i)Curation_Results")]
disk_basenames <- basename(disk_files)

# 5. Matching logic ---------------------------------------------------------------
# For each README entry, look for: exact match, case-insensitive match, or a
# match after stripping the entry's extension (covers the common case of a
# README listing a name without its extension).
match_entry <- function(entry) {
  if (entry %in% disk_basenames) {
    return(tibble(README_Entry = entry, Matched_File = entry, Match_Type = "Exact"))
  }
  ci_match <- disk_basenames[tolower(disk_basenames) == tolower(entry)]
  if (length(ci_match) > 0) {
    return(tibble(README_Entry = entry, Matched_File = ci_match[1], Match_Type = "Case-insensitive"))
  }
  entry_noext <- tools::file_path_sans_ext(entry)
  stem_match <- disk_basenames[tolower(tools::file_path_sans_ext(disk_basenames)) == tolower(entry_noext)]
  if (length(stem_match) > 0) {
    ext_note <- if (entry == entry_noext) "README entry has no extension" else "Extension differs"
    return(tibble(README_Entry = entry, Matched_File = stem_match[1], Match_Type = paste0("Matched by name only (", ext_note, ")")))
  }
  tibble(README_Entry = entry, Matched_File = NA_character_, Match_Type = "NO MATCH FOUND ON DISK")
}

readme_report <- map_dfr(readme_entries, match_entry)

# Files on disk with no corresponding README entry (by any of the match rules above)
matched_disk_files <- unique(na.omit(readme_report$Matched_File))
orphaned_files <- setdiff(disk_basenames, matched_disk_files)

orphan_report <- tibble(
  README_Entry = NA_character_,
  Matched_File = orphaned_files,
  Match_Type = "ON DISK, NOT LISTED IN README"
)

full_report <- bind_rows(readme_report, orphan_report)

# 6. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("README_FileList_Diff_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(full_report, output_file)

n_issues <- sum(full_report$Match_Type != "Exact")
message(sprintf("Process complete. %d of %d entries need attention (mismatched extension, name typo, or missing/orphaned file).",
                 n_issues, nrow(full_report)))
message(paste("Report saved to:", output_file))
