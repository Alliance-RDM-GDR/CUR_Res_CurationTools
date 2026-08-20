#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_dta_Script.R
# Description: Batch inspection of Stata files (Metadata Quality & PII).
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)      # Read/Write Stata .dta files
  library(labelled)   # Tools for variable labels
  library(tools)      # File utilities
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic (Hybrid)
# ------------------------------------------------------------------------------

if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Stata Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Usage: Rscript Inspect_dta_Script.R <input_dir> [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir))
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(sprintf("Inspecting Stata files in: %s", target_dir))
message(sprintf("Results will be saved to: %s", output_dir))


# ------------------------------------------------------------------------------
# 2. File Inventory
# ------------------------------------------------------------------------------
dta_files <- list.files(
  path = target_dir,
  pattern = "\\.dta$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(sprintf("Found %d Stata files.", length(dta_files)))


# ------------------------------------------------------------------------------
# 3. Part I: Metadata Health Check
# ------------------------------------------------------------------------------
message("--- Starting Metadata Health Check ---")

analyze_dta_health <- function(file_path) {
  
  fname <- basename(file_path)
  file_info <- file.info(file_path)
  
  tryCatch({
    # Read Data (Full read required for PII check, though slow for massive files)
    # For optimization on massive files, one might read n_max=1000 for metadata checks,
    # but that risks missing PII deeper in the file.
    data <- read_dta(file_path)
    
    n_vars <- ncol(data)
    n_obs <- nrow(data)
    
    # Metadata Quality
    var_labels <- map_lgl(data, ~ !is.null(attr(., "label")))
    pct_labeled <- if (n_vars > 0) round(100 * sum(var_labels) / n_vars, 1) else 0
    
    val_labels <- map_lgl(data, ~ !is.null(attr(., "labels")))
    has_val_labels <- any(val_labels)
    
    # Check for Stata's "Extended Missing Values" (.a - .z)
    # In R (haven), these are often mapped to NA but tagged.
    # A simple heuristic is checking numeric columns for specific NA types if strictly required,
    # but standard NA detection is usually sufficient for high-level screening.
    
    # PII Scan
    char_cols <- select(data, where(is.character))
    pii_found <- FALSE
    
    if (ncol(char_cols) > 0) {
      email_pattern <- "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
      sample_size <- min(n_obs, 1000)
      pii_check <- char_cols %>%
        slice_head(n = sample_size) %>%
        summarise(across(everything(), ~ any(str_detect(., email_pattern), na.rm = TRUE)))
      pii_found <- any(unlist(pii_check))
    }
    
    tibble(
      FileName = fname,
      Size_MB = round(file_info$size / 1024^2, 2),
      Vars = n_vars,
      Obs = n_obs,
      Label_Coverage_Pct = pct_labeled,
      Has_Value_Labels = has_val_labels,
      PII_Risk = pii_found,
      Status = "Success"
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname,
      Size_MB = round(file_info$size / 1024^2, 2),
      Vars = NA, Obs = NA, Label_Coverage_Pct = NA, Has_Value_Labels = NA, PII_Risk = NA,
      Status = paste("Read Failed:", e$message)
    )
  })
}

if (length(dta_files) > 0) {
  health_report <- purrr::map_dfr(dta_files, analyze_dta_health)
  
  health_file <- file.path(output_dir, paste0("DTA_Health_Check_HPC_", dir_label, "_", Sys.Date(), ".csv"))
  write_excel_csv(health_report, health_file)
  message(sprintf("Health Check saved to: %s", health_file))
}


# ------------------------------------------------------------------------------
# 4. Part II: Dictionary Extraction
# ------------------------------------------------------------------------------
message("--- Starting Dictionary Extraction ---")

extract_dictionary <- function(file_path) {
  tryCatch({
    # Read header only for efficiency
    data <- read_dta(file_path, n_max = 1) 
    
    map_dfr(names(data), function(var) {
      lbl <- attr(data[[var]], "label")
      if (is.null(lbl)) lbl <- NA_character_
      
      # Extract value labels (first 3 examples)
      val_lbls <- attr(data[[var]], "labels")
      val_str <- if (!is.null(val_lbls)) {
        paste(head(names(val_lbls), 3), collapse = "; ")
      } else {
        NA_character_
      }
      
      tibble(
        FileName = basename(file_path),
        Variable = var,
        Label = lbl,
        Type = typeof(data[[var]]),
        Value_Examples = val_str
      )
    })
  }, error = function(e) NULL)
}

if (length(dta_files) > 0) {
  full_dictionary <- map_dfr(dta_files, extract_dictionary)
  
  dict_file <- file.path(output_dir, paste0("DTA_Data_Dictionary_HPC_", dir_label, "_", Sys.Date(), ".csv"))
  write_excel_csv(full_dictionary, dict_file)
  message(sprintf("Data Dictionary saved to: %s", dict_file))
}