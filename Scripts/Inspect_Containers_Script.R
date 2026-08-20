#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Archive_Script.R
# Purpose: Batch inspection of compressed archives (.zip, .tar, .7z, etc.).
#          - Detects "Zip Bombs" (High compression ratio)
#          - Checks Integrity (Corrupt headers)
#          - Inventories contents without extraction
# Usage:   Rscript Inspect_Archive_Script.R <target_directory>
# ==============================================================================

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(archive)
  library(fs)
})

# Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Archive Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_Containers")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_Archive_Script.R /path/to/archives [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_Containers")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting Archive analysis on:", target_dir))

# Inventory -----------------------------------------------------------------
archive_files <- list.files(
  path = target_dir,
  pattern = "\\.(zip|tar|tar\\.gz|tgz|7z|rar)$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(archive_files), "archive files."))

if (length(archive_files) == 0) {
  message("No archives found. Exiting.")
  quit(status = 0)
}

# Processing Function -------------------------------------------------------
inspect_archive <- function(fp) {
  fname <- basename(fp)
  
  tryCatch({
    # Physical Size
    size_compressed_bytes <- file.size(fp)
    
    # Read Manifest (Non-invasive)
    contents <- archive::archive(fp)
    
    # Metrics
    file_count <- nrow(contents)
    size_extracted_bytes <- sum(contents$size)
    
    # Ratio
    ratio <- if(size_compressed_bytes > 0) size_extracted_bytes / size_compressed_bytes else 0
    
    # Content Profiling
    extensions <- fs::path_ext(contents$path)
    top_exts <- names(sort(table(extensions), decreasing = TRUE))[1:3]
    content_summary <- paste(top_exts, collapse = ", ")
    
    has_nested <- any(extensions %in% c("zip", "tar", "gz", "7z", "rar"))
    
    tibble(
      FileName = fname,
      FileCount = file_count,
      Compressed_MB = round(size_compressed_bytes / 1024^2, 2),
      Extracted_MB = round(size_extracted_bytes / 1024^2, 2),
      CompressionRatio = round(ratio, 1),
      ContentTypes = content_summary,
      HasNestedArchives = has_nested,
      Status = "Success"
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname, FileCount = NA, Compressed_MB = NA, 
      Extracted_MB = NA, CompressionRatio = NA, ContentTypes = NA,
      HasNestedArchives = NA,
      Status = paste("Corrupt/Unreadable:", e$message)
    )
  })
}

# Execution -----------------------------------------------------------------
message("Generating Archive Manifests...")
report <- map_dfr(archive_files, inspect_archive)

# Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("Containers_Manifest_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(report, output_file)
message(paste("✅ Process Complete."))
message(paste("   Analyzed:", length(unique(report$FileName)), "files"))
message(paste("   Report saved to:", output_file))