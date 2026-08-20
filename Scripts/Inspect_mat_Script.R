#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_mat_Script.R
# Purpose: Batch inspection of MATLAB (.mat) files.
#          - Detects Version (v5 vs v7.3/HDF5) via binary header.
#          - Adaptive Extraction: Uses R.matlab for v5, rhdf5 for v7.3.
# Usage:   Rscript Inspect_mat_Script.R <target_directory>
# ==============================================================================

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(stringr)
  library(R.matlab) # For v5 files
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select MAT-file Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_mat")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_mat_Script.R /path/to/mat_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_mat")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# Check for rhdf5 (Essential for v7.3)
if (!require("rhdf5", quietly = TRUE)) {
  stop("CRITICAL ERROR: Package 'rhdf5' is missing.\nOn HPC, please ensure Bioconductor libraries are installed or loaded via module.", call. = FALSE)
}

message(paste("Starting MAT-file analysis on:", target_dir))

# 2. Define Extraction Functions -----------------------------------------------

# --- Helper A: Extract v5 Content ---
extract_v5_content <- function(fp) {
  tryCatch({
    content <- R.matlab::readMat(fp)
    var_names <- names(content)
    
    map_dfr(var_names, function(v) {
      obj <- content[[v]]
      dims <- paste(dim(obj), collapse = "x")
      if (dims == "") dims <- paste(length(obj), "(len)")
      
      tibble(
        object_path = v,
        object_type = "MATLAB Variable",
        dimensions = dims,
        data_class = class(obj)[1]
      )
    })
  }, error = function(e) {
    tibble(object_path = "Parse Error", object_type = "Error", dimensions = NA, data_class = e$message)
  })
}

# --- Helper B: Extract v7.3 Content (HDF5) ---
extract_v73_content <- function(fp) {
  tryCatch({
    content <- rhdf5::h5ls(fp, all = TRUE)
    content %>%
      mutate(
        object_path = paste0(group, "/", name),
        object_path = str_replace_all(object_path, "//", "/")
      ) %>%
      select(
        object_path,
        object_type = otype,  # e.g., H5I_DATASET
        dimensions = dim,
        data_class = dclass     # e.g., H5T_FLOAT
      )
  }, error = function(e) {
    tibble(object_path = "HDF5 Error", object_type = "Error", dimensions = NA, data_class = e$message)
  })
}

# --- Main Processor ---
inspect_mat_file <- function(fp) {
  fname <- basename(fp)
  
  # 1. Header Check (Identify Version)
  # Read first 128 bytes to avoid loading full file
  con <- file(fp, "rb")
  header_raw <- tryCatch(readBin(con, "raw", n = 128), finally = close(con))
  header_txt <- rawToChar(header_raw[header_raw > 31 & header_raw < 127])
  
  # Detect HDF5 signature
  is_hdf5 <- str_detect(header_txt, "HDF5") || str_detect(header_txt, "MATLAB 7.3")
  version_label <- if (is_hdf5) "v7.3 (HDF5)" else "v5 (Standard)"
  
  # 2. Branching Logic
  if (is_hdf5) {
    content_df <- extract_v73_content(fp)
  } else {
    content_df <- extract_v5_content(fp)
  }
  
  # 3. Add Metadata
  content_df %>%
    mutate(
      filename = fname,
      version = version_label
    ) %>%
    select(filename, version, everything())
}

# 3. Execution Phase -----------------------------------------------------------
mat_files <- list.files(
  path = target_dir, 
  pattern = "\\.mat$", 
  recursive = TRUE, 
  full.names = TRUE
)

message(paste("Found", length(mat_files), "MAT-files."))

if (length(mat_files) == 0) {
  message("No files to process. Exiting.")
  quit(status = 0)
}

message("Deep scanning structure (This may take time for large v7.3 files)...")

# Process using map_dfr for clean data binding
results <- map_dfr(mat_files, inspect_mat_file)

# 4. Export Phase --------------------------------------------------------------
output_file <- file.path(output_dir, paste0("MAT_Deep_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(results, output_file)

message(paste("✅ Process Complete."))
message(paste("   Extracted:", nrow(results), "objects/variables"))
message(paste("   Report saved to:", output_file))