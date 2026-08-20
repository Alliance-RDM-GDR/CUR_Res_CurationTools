#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_CSV_Script.R
# Description: Batch inspection of CSV files (Health Check + Profiling).
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(skimr)
  library(tools)
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic (Hybrid)
# ------------------------------------------------------------------------------

if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Data Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_csv")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Usage: Rscript Inspect_CSV_Script.R <input_dir> [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir))
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(sprintf("Inspecting CSVs in: %s", target_dir))
message(sprintf("Results will be saved to: %s", output_dir))


# ------------------------------------------------------------------------------
# 2. File Inventory
# ------------------------------------------------------------------------------
csv_files <- list.files(
  path = target_dir,
  pattern = "\\.csv$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(sprintf("Found %d CSV files.", length(csv_files)))


# ------------------------------------------------------------------------------
# 3. Part I: Health Check Function
# ------------------------------------------------------------------------------
message("--- Starting Health Check ---")

analyze_csv_health <- function(file_path) {
  fname <- basename(file_path)
  file_info <- file.info(file_path)
  
  guess <- readr::guess_encoding(file_path, n_max = 1000)
  likely_encoding <- if (nrow(guess) > 0) guess$encoding[1] else "Unknown"
  
  tryCatch({
    df <- read_csv(file_path, locale = locale(encoding = likely_encoding), 
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
    
    tibble(
      FileName = fname,
      Size_MB = round(file_info$size / 1024^2, 2),
      Encoding = likely_encoding,
      Rows = n_rows,
      Cols = n_cols,
      Pct_Complete = pct_complete,
      Duplicate_Rows = n_duplicates,
      PII_Risk = pii_found,
      Status = "Success"
    )
  }, error = function(e) {
    tibble(
      FileName = fname,
      Size_MB = round(file_info$size / 1024^2, 2),
      Encoding = likely_encoding,
      Rows = NA, Cols = NA, Pct_Complete = NA, Duplicate_Rows = NA, PII_Risk = NA,
      Status = paste("Read Failed:", e$message)
    )
  })
}

if (length(csv_files) > 0) {
  health_report <- purrr::map_dfr(csv_files, analyze_csv_health)
  
  health_file <- file.path(output_dir, paste0("CSV_Health_Check_", dir_label, "_", Sys.Date(), ".csv"))
  write_excel_csv(health_report, health_file)
  message(sprintf("Health Check saved to: %s", health_file))
}

# ------------------------------------------------------------------------------
# 4. Part II: Detailed Profiling
# ------------------------------------------------------------------------------
message("--- Starting Detailed Profiling ---")

safe_skim <- function(file_path) {
  tryCatch({
    df <- read_csv(file_path, show_col_types = FALSE)
    skim(df) %>%
      as_tibble() %>%
      select(-any_of("numeric.hist")) %>%  # sparkline glyphs: unreadable/fragile in a flat CSV
      mutate(FileName = basename(file_path)) %>%
      select(FileName, everything())
  }, error = function(e) NULL)
}

if (length(csv_files) > 0) {
  full_profile_data <- map_dfr(csv_files, safe_skim)
  
  profile_file <- file.path(output_dir, paste0("CSV_Full_Profile_", dir_label, "_", Sys.Date(), ".csv"))
  write_excel_csv(full_profile_data, profile_file)
  message(sprintf("Detailed Profile saved to: %s", profile_file))
}