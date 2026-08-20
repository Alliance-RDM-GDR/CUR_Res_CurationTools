#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_json_Script.R
# Purpose: Batch inspection of JSON files for archival quality.
#          Identifies Structure (Data Frame vs List), Dimensions, and Complexity.
# Usage:   Rscript Inspect_json_Script.R <target_directory>
# ==============================================================================

# Load libraries silently to keep logs clean
suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select JSON Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_json")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_json_Script.R /path/to/json_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_json")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting JSON analysis on:", target_dir))

# 2. Define Helper Functions ---------------------------------------------------

# Recursive function to calculate maximum nesting depth
get_depth <- function(x) {
  if (is.list(x) && length(x) > 0) {
    1 + max(vapply(x, get_depth, numeric(1)), 0)
  } else {
    0
  }
}

# 3. Inventory Files -----------------------------------------------------------
json_files <- list.files(
  path = target_dir, 
  pattern = "\\.json$", 
  recursive = TRUE, 
  full.names = TRUE
)

message(paste("Found", length(json_files), "JSON files."))

if (length(json_files) == 0) {
  message("No JSON files found. Exiting.")
  quit(status = 0)
}

# 4. Processing Loop -----------------------------------------------------------
# We use a list to store results for memory efficiency before binding
json_summary_list <- list()

message("Parsing files...")

for (file_path in json_files) {
  file_name <- basename(file_path)
  
  tryCatch({
    # PASS 1: Usability Check (Simplify = TRUE)
    # This determines if it looks like a Data Frame (Table) to an R user
    json_data <- jsonlite::fromJSON(file_path, simplifyVector = TRUE)
    
    # PASS 2: Complexity Check (Simplify = FALSE)
    # We re-parse without simplification to accurately count the tree depth
    raw_data <- jsonlite::fromJSON(file_path, simplifyVector = FALSE)
    depth_val <- get_depth(raw_data)
    
    # Determine Class (Data Frame, List, or Vector)
    obj_class <- class(json_data)[1]
    
    # Determine Dimensions & Keys based on type
    if (is.data.frame(json_data)) {
      dims_str <- paste(dim(json_data), collapse = " x ")
      keys_str <- paste(head(colnames(json_data), 5), collapse = ", ")
      if (ncol(json_data) > 5) keys_str <- paste(keys_str, "...")
      
    } else if (is.list(json_data)) {
      dims_str <- paste(length(json_data), "elements")
      keys_str <- paste(head(names(json_data), 5), collapse = ", ")
      if (length(json_data) > 5) keys_str <- paste(keys_str, "...")
      
    } else {
      # Atomic vectors or arrays
      dims_str <- paste(length(json_data), "length")
      keys_str <- "(No Keys - Flat Array)"
    }
    
    # Store success result
    json_summary_list[[length(json_summary_list) + 1]] <- tibble(
      filename = file_name,
      is_valid = TRUE,
      structure_type = obj_class,
      dimensions = dims_str,
      top_level_keys = keys_str,
      max_depth = depth_val,
      error_msg = NA_character_
    )
    
  }, error = function(e) {
    # Store error result
    json_summary_list[[length(json_summary_list) + 1]] <- tibble(
      filename = file_name,
      is_valid = FALSE,
      structure_type = "Error",
      dimensions = "NA",
      top_level_keys = "NA",
      max_depth = NA_real_,
      error_msg = e$message
    )
  })
}

# 5. Export Results ------------------------------------------------------------
results <- bind_rows(json_summary_list)

output_file <- file.path(output_dir, paste0("JSON_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(results, output_file)

message(paste("✅ Process Complete."))
message(paste("   Analyzed:", nrow(results), "files"))
message(paste("   Report saved to:", output_file))