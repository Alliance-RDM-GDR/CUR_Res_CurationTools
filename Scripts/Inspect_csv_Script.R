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

csv_files <- csv_files[!grepl("Curation_Results", csv_files, ignore.case = TRUE)]

message(sprintf("Found %d CSV files.", length(csv_files)))


# ------------------------------------------------------------------------------
# 2b. Delimiter Detection
# ------------------------------------------------------------------------------
# A ".csv" file is not guaranteed to be comma-delimited — European/French-locale
# exports commonly use semicolons (since comma is the decimal separator there).
# Reading a semicolon-delimited file with a hardcoded comma silently "succeeds"
# as a single-column file instead of failing, so this must be detected, not assumed.
detect_delimiter <- function(file_path) {
  first_line <- tryCatch(readLines(file_path, n = 1, warn = FALSE), error = function(e) "")
  if (length(first_line) == 0) return(",")
  candidates <- c("," = ",", ";" = ";", "\t" = "\t", "|" = "|")
  counts <- purrr::map_int(candidates, ~ lengths(regmatches(first_line, gregexpr(.x, first_line, fixed = TRUE))))
  candidates[[which.max(counts)]]
}

# ------------------------------------------------------------------------------
# 3. Part I: Health Check Function
# ------------------------------------------------------------------------------
message("--- Starting Health Check ---")

analyze_csv_health <- function(file_path) {
  fname <- basename(file_path)
  file_info <- file.info(file_path)

  guess <- readr::guess_encoding(file_path, n_max = 1000)
  likely_encoding <- if (nrow(guess) > 0) guess$encoding[1] else "Unknown"
  delim <- detect_delimiter(file_path)

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
    
    # Column-name screen: PII_Risk above only looks for email patterns in values,
    # so a file with columns like "Surname" or "D.O.B" can still read PII_Risk = FALSE.
    pii_name_pattern <- "surname|last.?name|family.?name|given.?name|first.?name|full.?name|^name$|d\\.?o\\.?b|birth|address|street|postal|zip.?code|phone|e-?mail|\\bsin\\b|ssn|health.?card|\\bmrn\\b|initials"
    pii_cols <- names(df)[str_detect(names(df), regex(pii_name_pattern, ignore_case = TRUE))]

    tibble(
      FileName = fname,
      Delimiter = c(","=",", ";"=";", "\t"="Tab", "|"="|")[[delim]],
      Size_MB = round(file_info$size / 1024^2, 2),
      Encoding = likely_encoding,
      Rows = n_rows,
      Cols = n_cols,
      Pct_Complete = pct_complete,
      Duplicate_Rows = n_duplicates,
      PII_Risk = pii_found,
      PII_Suspect_Columns = paste(pii_cols, collapse = "; "),
      Status = "Success"
    )
  }, error = function(e) {
    tibble(
      FileName = fname,
      Delimiter = c(","=",", ";"=";", "\t"="Tab", "|"="|")[[delim]],
      Size_MB = round(file_info$size / 1024^2, 2),
      Encoding = likely_encoding,
      Rows = NA, Cols = NA, Pct_Complete = NA, Duplicate_Rows = NA, PII_Risk = NA, PII_Suspect_Columns = NA,
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
# 3b. Codebooks: describe the columns in Health_Check and Full_Profile
# ------------------------------------------------------------------------------
# Warn (rather than fail) if a report has columns the codebook doesn't
# describe yet, so schema drift is visible instead of silently undocumented.
warn_undocumented_columns <- function(data, codebook, report_name) {
  undocumented <- setdiff(names(data), codebook$Variable)
  if (length(undocumented) > 0) {
    warning(sprintf(
      "%s has column(s) not described in its codebook: %s. Update the codebook in this script.",
      report_name, paste(undocumented, collapse = ", ")
    ), call. = FALSE)
  }
}

health_codebook <- tibble(
  Variable = c("FileName", "Delimiter", "Size_MB", "Encoding", "Rows", "Cols", "Pct_Complete",
               "Duplicate_Rows", "PII_Risk", "PII_Suspect_Columns", "Status"),
  Type = c("Text", "Text", "Numeric", "Text", "Integer", "Integer", "Numeric (0-100)",
           "Integer", "Logical", "Text", "Text"),
  Description = c(
    "Name of the CSV file (no path).",
    "Delimiter auto-detected from the first line (',', ';', Tab, or '|') — a \".csv\" extension does not guarantee a comma delimiter, especially from European/French-locale software.",
    "File size in megabytes.",
    "Character encoding detected via readr::guess_encoding() (e.g. UTF-8, ISO-8859-1).",
    "Number of data rows read.",
    "Number of columns read.",
    "Percentage of non-missing cells across the whole file.",
    "Count of exact duplicate rows.",
    "TRUE if an email-like pattern was found in a character column (checked in the first 1000 rows). Values only; see PII_Suspect_Columns for column names.",
    "Column names suggesting personal data (name, surname, date of birth, address, phone, email, initials, etc.), semicolon-separated. Name-based heuristic: a hit needs a human look, an empty result is not proof of no PII.",
    'Either "Success", or "Read Failed: <error message>" if the file could not be parsed.'
  )
)

if (length(csv_files) > 0) {
  warn_undocumented_columns(health_report, health_codebook, "CSV_Health_Check")
  codebook_file <- file.path(output_dir, "CSV_Health_Check_Codebook.csv")
  write_excel_csv(health_codebook, codebook_file)
  message(sprintf("Health Check codebook saved to: %s", codebook_file))
}

# ------------------------------------------------------------------------------
# 4. Part II: Detailed Profiling
# ------------------------------------------------------------------------------
message("--- Starting Detailed Profiling ---")

safe_skim <- function(file_path) {
  tryCatch({
    df <- read_delim(file_path, delim = detect_delimiter(file_path), show_col_types = FALSE)
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

  # Codebook: standard skimr summary-statistic columns, plus FileName which
  # this script adds. character.* columns are NA for non-character variables,
  # and numeric.* columns are NA for non-numeric variables — skimr only
  # reports the statistics that apply to each variable's type.
  profile_codebook <- tibble(
    Variable = c("FileName", "skim_type", "skim_variable", "n_missing", "complete_rate",
                 "character.min", "character.max", "character.empty", "character.n_unique",
                 "character.whitespace", "numeric.mean", "numeric.sd", "numeric.p0",
                 "numeric.p25", "numeric.p50", "numeric.p75", "numeric.p100"),
    Type = c("Text", "Text", "Text", "Integer", "Numeric (0-1)", "Integer", "Integer",
             "Integer", "Integer", "Integer", "Numeric", "Numeric", "Numeric",
             "Numeric", "Numeric", "Numeric", "Numeric"),
    Description = c(
      "Which source file this row's statistics belong to (added by this script, not skimr).",
      "R data type skimr assigned to the variable (character, numeric, logical, Date, ...).",
      "Column name from the source CSV.",
      "Count of missing (NA) values.",
      "Proportion of non-missing values.",
      "Shortest string length observed (character columns only).",
      "Longest string length observed (character columns only).",
      'Count of empty strings "" (character columns only).',
      "Count of distinct values (character columns only).",
      "Count of values that are entirely whitespace (character columns only).",
      "Mean (numeric columns only).",
      "Standard deviation (numeric columns only).",
      "Minimum value (numeric columns only).",
      "25th percentile (numeric columns only).",
      "Median / 50th percentile (numeric columns only).",
      "75th percentile (numeric columns only).",
      "Maximum value (numeric columns only)."
    )
  )
  warn_undocumented_columns(full_profile_data, profile_codebook, "CSV_Full_Profile")
  profile_codebook_file <- file.path(output_dir, "CSV_Full_Profile_Codebook.csv")
  write_excel_csv(profile_codebook, profile_codebook_file)
  message(sprintf("Full Profile codebook saved to: %s", profile_codebook_file))
}