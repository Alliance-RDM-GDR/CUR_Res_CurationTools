#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
# TITLE: JSON File Inspector
# DESCRIPTION: Scans a directory for .json files, validates them, and 
#              reports on structure, dimensions, and top-level keys.
# USAGE:
#   Interactive: Source in RStudio -> Select Directory
#   CLI/HPC:     Rscript check_json.R /path/to/data_folder
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(rstudioapi))

# --- 1. GET TARGET DIRECTORY ---
target_dir <- ""
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  target_dir <- rstudioapi::selectDirectory(caption = "Select JSON Directory")
  if (is.null(target_dir)) stop("No directory selected.", call. = FALSE)
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) stop("No path provided. Usage: Rscript check_json.R <path>", call. = FALSE)
  target_dir <- args[1]
}

if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir), call. = FALSE)
message(paste("Analyzing:", target_dir))

# --- 2. FIND FILES ---
json_files <- list.files(target_dir, pattern = "\\.json$", 
                         recursive = TRUE, full.names = TRUE, ignore.case = TRUE)

if (length(json_files) == 0) stop("No .json files found.", call. = FALSE)
message(paste("Found", length(json_files), "JSON files."))

# --- 3. PROCESS FILES ---
message("Generating structure report...")
json_summary_list <- list()

for (file_path in json_files) {
  file_name <- basename(file_path)
  
  tryCatch({
    # Read JSON
    json_data <- fromJSON(file_path, simplifyVector = TRUE)
    obj_class <- class(json_data)[1]
    
    # Logic to extract dims and keys based on type
    if (is.data.frame(json_data)) {
      dims_str <- paste(dim(json_data), collapse = " x ")
      keys_str <- paste(head(colnames(json_data), 5), collapse = ", ")
      if (ncol(json_data) > 5) keys_str <- paste(keys_str, "...")
      
    } else if (is.list(json_data)) {
      dims_str <- paste(length(json_data), "elements")
      keys_str <- paste(head(names(json_data), 5), collapse = ", ")
      if (length(json_data) > 5) keys_str <- paste(keys_str, "...")
      
    } else {
      dims_str <- paste(length(json_data), "length")
      keys_str <- "(No Keys - Flat Array)"
    }
    
    json_summary_list[[length(json_summary_list) + 1]] <- tibble(
      FileName = file_name, IsValid = TRUE, StructureType = obj_class,
      Dimensions = dims_str, TopLevelKeys = keys_str
    )
    
  }, error = function(e) {
    json_summary_list[[length(json_summary_list) + 1]] <- tibble(
      FileName = file_name, IsValid = FALSE, StructureType = "Error",
      Dimensions = "NA", TopLevelKeys = paste("Parse Error:", e$message)
    )
  })
}

# --- 4. SAVE RESULTS ---
json_report <- bind_rows(json_summary_list)
out_dir <- file.path(getwd(), "Results", "JsonChecker")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(out_dir, paste0("JSON_Report_", Sys.Date(), ".csv"))

write.csv(json_report, output_file, row.names = FALSE)
message(paste("Done. Report saved to:", output_file))