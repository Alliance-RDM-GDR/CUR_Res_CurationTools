#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Archive_Script.R
# Purpose: Batch inspection of compressed archives (.zip, .tar, .7z, etc.).
#          - Detects "Zip Bombs" (High compression ratio)
#          - Checks Integrity (Corrupt headers)
#          - Inventories contents without extraction
# Usage:   Rscript Inspect_Archive_Script.R <target_directory>
# ==============================================================================

# Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_Archive_Script.R /path/to/archives", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(archive)
  library(fs)
})

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
output_dir <- "Results/Inspect_Containers"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, paste0("Containers_Manifest_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write.csv(report, output_file, row.names = FALSE)
message(paste("✅ Process Complete."))
message(paste("   Analyzed:", length(unique(report$FileName)), "files"))
message(paste("   Report saved to:", output_file))