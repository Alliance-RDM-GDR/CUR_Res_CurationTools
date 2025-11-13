#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
#
# TITLE: Image File Metadata and Quality Control
# AUTHOR: Natalie Williams 
# DATE: 2025-11-13
#
# DESCRIPTION:
# This script performs standardized quality control checks on image files.
# It scans a directory, extracts technical metadata using 'magick' and 
# detailed EXIF data using 'exiftoolr', and generates summary reports.
#
# USAGE:
#
# 1. INTERACTIVE (RStudio):
#    - Source this script. A dialog box will appear to select a directory.
#
# 2. NON-INTERACTIVE (HPC / Command-Line):
#    - Rscript check_images.R /path/to/your/data_folder
#
# REQUIREMENTS:
#    - R packages: tidyverse, magick, exiftoolr
#    - System software: ExifTool (must be installed via exiftoolr::install_exiftool()
#      or available on the system path).
#
# ---------------------------------------------------------------------------


# --- 1. SETUP: Load Libraries ---
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(magick))
suppressPackageStartupMessages(library(exiftoolr))


# --- 2. GET TARGET DIRECTORY ---
target_dir <- ""

if (interactive()) {
  # INTERACTIVE MODE
  message("Running in interactive mode. Please select a directory.")
  target_dir <- rstudioapi::selectDirectory()
  if (is.null(target_dir)) {
    stop("No directory selected. Script aborted.", call. = FALSE)
  }
} else {
  # NON-INTERACTIVE MODE
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    stop("No directory path provided. Usage: Rscript check_images.R /path/to/folder", call. = FALSE)
  } else {
    target_dir <- args[1]
    if (!dir.exists(target_dir)) {
      stop(paste("Directory does not exist:", target_dir), call. = FALSE)
    }
  }
}

message(paste("Analyzing directory:", target_dir))


# --- 3. FIND IMAGE FILES ---
message("Finding image files...")
# Using regex to find common image extensions
image_files <- list.files(
  path = target_dir,
  pattern = "\\.(jpg|jpeg|png|tiff|tif)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(image_files) == 0) {
  stop("No image files found in the specified directory.", call. = FALSE)
}

message(paste("Found", length(image_files), "image files."))


# --- 4. MAGICK TECHNICAL SUMMARY ---
message("Running 'magick' technical summary...")

# Use purrr::map_dfr to loop through files safely
magick_info <- purrr::map_dfr(image_files, function(file_path) {
  tryCatch({
    # image_read() validates the file, image_info() extracts metadata
    image_read(file_path) %>%
      image_info() %>%
      mutate(SourceFile = file_path)
  }, error = function(e) {
    message("Could not process file with magick: ", file_path, " | Error: ", e$message)
    return(NULL)
  })
})


# --- 5. EXIFTOOL DETAILED SUMMARY ---
message("Running 'exiftool' detailed extraction...")

# exif_read processes all files at once
# Note: ExifTool must be installed on the system for this to work
exif_info <- tryCatch({
  exif_read(image_files)
}, error = function(e) {
  message("Error running ExifTool. Ensure it is installed. Error: ", e$message)
  return(NULL)
})


# --- 6. WRITE RESULTS TO FILE ---
message("Writing results to file...")

# Define output directory
output_dir <- file.path(getwd(), "Results", "FileChecks_Images")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Save Magick Results
if (nrow(magick_info) > 0) {
  write.csv(
    magick_info, 
    file = file.path(output_dir, paste0("Image_Metadata_Magick_", Sys.Date(), ".csv")), 
    row.names = FALSE
  )
  message("Magick metadata saved.")
}

# Save ExifTool Results
if (!is.null(exif_info) && nrow(exif_info) > 0) {
  write.csv(
    exif_info,
    file = file.path(output_dir, paste0("Image_Metadata_Exif_", Sys.Date(), ".csv")),
    row.names = FALSE
  )
  message("ExifTool metadata saved.")
} else {
  message("No ExifTool data to save.")
}

message(paste("Summary files created in:", output_dir))
message("Process complete.")