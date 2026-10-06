#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_DelimitedText_Script.R
# Purpose: Health check + profiling for tabular data delivered as .txt
#          (tab/semicolon/pipe-delimited instrument or export files that are
#          not proper .csv). Mirrors Inspect_CSV_Script.R's health-check
#          logic; use it for tabular content that Inspect_Text_Script.R would
#          otherwise treat as unstructured prose.
# Usage:   Rscript Inspect_DelimitedText_Script.R <target_directory>
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Delimited Text Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_DelimitedText")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_DelimitedText_Script.R /path/to/txt_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_DelimitedText")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting delimited-text analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
txt_files <- list.files(
  path = target_dir,
  pattern = "\\.txt$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

txt_files <- txt_files[!grepl("Curation_Results", txt_files, ignore.case = TRUE)]

message(paste("Found", length(txt_files), ".txt file(s)."))

if (length(txt_files) == 0) {
  message("No .txt files found. Exiting.")
  quit(status = 0)
}

# 3. Delimiter Detection --------------------------------------------------------
# Picks whichever candidate delimiter is most frequent in the first line.
# A file that isn't actually delimited data (e.g. prose) will show low, roughly
# equal counts for all candidates and gets flagged via low column count downstream.
detect_delimiter <- function(file_path) {
  first_line <- tryCatch(readLines(file_path, n = 1, warn = FALSE), error = function(e) "")
  if (length(first_line) == 0) return("\t")
  candidates <- c("\t" = "\t", "," = ",", ";" = ";", "|" = "|")
  counts <- purrr::map_int(candidates, ~ lengths(regmatches(first_line, gregexpr(.x, first_line, fixed = TRUE))))
  candidates[[which.max(counts)]]
}

# 4. Health Check Function ------------------------------------------------------
analyze_delimited_health <- function(file_path) {
  fname <- basename(file_path)
  file_info <- file.info(file_path)

  delim <- detect_delimiter(file_path)
  guess <- readr::guess_encoding(file_path, n_max = 1000)
  likely_encoding <- if (nrow(guess) > 0) guess$encoding[1] else "Unknown"

  tryCatch({
    df <- read_delim(file_path, delim = delim, locale = locale(encoding = likely_encoding),
                      show_col_types = FALSE, progress = FALSE)

    n_rows <- nrow(df)
    n_cols <- ncol(df)
    total_cells <- n_rows * n_cols
    n_missing <- sum(is.na(df))
    pct_complete <- if (total_cells > 0) round(100 * (1 - n_missing / total_cells), 2) else 0
    n_duplicates <- sum(duplicated(df))

    char_cols <- select(df, where(is.character))
    email_pattern <- "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
    pii_found <- FALSE

    if (ncol(char_cols) > 0) {
      sample_size <- min(n_rows, 1000)
      pii_check <- char_cols %>%
        slice_head(n = sample_size) %>%
        summarise(across(everything(), ~ any(str_detect(., email_pattern), na.rm = TRUE)))
      pii_found <- any(unlist(pii_check))
    }

    delim_label <- c("\t" = "Tab", "," = "Comma", ";" = "Semicolon", "|" = "Pipe")[[delim]]

    tibble(
      FileName = fname,
      Delimiter = delim_label,
      Size_MB = round(file_info$size / 1024^2, 2),
      Encoding = likely_encoding,
      Rows = n_rows,
      Cols = n_cols,
      Pct_Complete = pct_complete,
      Duplicate_Rows = n_duplicates,
      PII_Risk = pii_found,
      LikelyNonTabular = n_cols <= 1,
      Status = "Success"
    )
  }, error = function(e) {
    tibble(
      FileName = fname, Delimiter = NA, Size_MB = round(file_info$size / 1024^2, 2),
      Encoding = likely_encoding, Rows = NA, Cols = NA, Pct_Complete = NA,
      Duplicate_Rows = NA, PII_Risk = NA, LikelyNonTabular = NA,
      Status = paste("Read Failed:", e$message)
    )
  })
}

# 5. Execution & Codebook --------------------------------------------------------
health_report <- purrr::map_dfr(txt_files, analyze_delimited_health)

health_file <- file.path(output_dir, paste0("DelimitedText_Health_Check_", dir_label, "_", Sys.Date(), ".csv"))
write_excel_csv(health_report, health_file)
message(sprintf("Health Check saved to: %s", health_file))

codebook <- tibble(
  Variable = c("FileName", "Delimiter", "Size_MB", "Encoding", "Rows", "Cols",
               "Pct_Complete", "Duplicate_Rows", "PII_Risk", "LikelyNonTabular", "Status"),
  Type = c("Text", "Text", "Numeric", "Text", "Integer", "Integer", "Numeric (0-100)",
           "Integer", "Logical", "Logical", "Text"),
  Description = c(
    "Name of the .txt file (no path).",
    "Delimiter auto-detected from the first line (Tab, Comma, Semicolon, or Pipe).",
    "File size in megabytes.",
    "Character encoding detected via readr::guess_encoding().",
    "Number of data rows read.",
    "Number of columns read.",
    "Percentage of non-missing cells across the whole file.",
    "Count of exact duplicate rows.",
    "TRUE if an email-like pattern was found in a character column (checked in the first 1000 rows).",
    "TRUE if only one column was detected, suggesting the file is not actually delimited tabular data (e.g. prose or a README).",
    'Either "Success", or "Read Failed: <error message>" if the file could not be parsed.'
  )
)
codebook_file <- file.path(output_dir, "DelimitedText_Health_Check_Codebook.csv")
write_excel_csv(codebook, codebook_file)
message(sprintf("Codebook saved to: %s", codebook_file))
