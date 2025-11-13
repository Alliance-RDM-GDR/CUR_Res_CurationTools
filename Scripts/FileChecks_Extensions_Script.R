#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
#
# TITLE: File Extension and Inventory Check
# AUTHOR: Natalie Williams (Adapted by Gemini)
# DATE: 2025-11-13
#
# DESCRIPTION:
# This script provides a utility to inventory the contents of a data directory.
# It recursively scans a target folder, identifies all files (including hidden),
# and generates a summary table counting the occurrences of each unique file extension.
#
# USAGE:
#
# 1. INTERACTIVE (RStudio):
#    - Open this script in RStudio.
#    - Click the "Source" button.
#    - A dialog box will appear asking you to select a directory.
#
# 2. NON-INTERACTIVE (HPC / Command-Line):
#    - Run this script from your terminal or a batch script.
#    - Provide the path to the target directory as the first argument.
#    - Example:
#      Rscript check_extensions.R /path/to/your/data_folder
#
# ---------------------------------------------------------------------------


# --- 1. SETUP: Load Libraries ---
# (You may need to run install.packages(c("tidyverse", "rstudioapi")) once)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(rstudioapi))


# --- 2. GET TARGET DIRECTORY ---
# This block handles both interactive and non-interactive use.

target_dir <- ""

if (interactive()) {
  # INTERACTIVE MODE (e.g., RStudio)
  # Show a pop-up dialog to select the folder.
  message("Running in interactive mode. Please select a directory.")
  target_dir <- rstudioapi::selectDirectory()
  if (is.null(target_dir)) {
    stop("No directory selected. Script aborted.", call. = FALSE)
  }
} else {
  # NON-INTERACTIVE MODE (e.g., HPC or command-line)
  # Get directory from command-line arguments.
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    stop("No directory path provided. Usage: Rscript check_extensions.R /path/to/folder", call. = FALSE)
  } else {
    target_dir <- args[1]
    if (!dir.exists(target_dir)) {
      stop(paste("Directory does not exist:", target_dir), call. = FALSE)
    }
  }
}

message(paste("Analyzing directory:", target_dir))


# --- 3. FIND ALL FILES ---
# Searches the target directory and all subdirectories
# for all files, including hidden ones.

message("Finding all files...")
all_files <- list.files(
  path = target_dir,
  recursive = TRUE,
  full.names = TRUE, # Get the full path for robustness
  all.files = TRUE   # Include dotfiles (e.g., .git, .Rproj)
)

if (length(all_files) == 0) {
  stop("No files found in the specified directory.", call. = FALSE)
}

message(paste("Found", length(all_files), "total files (including hidden)."))


# --- 4. EXTRACT EXTENSIONS & GENERATE SUMMARY ---
# 1. Isolates the file extension from each path.
# 2. Counts occurrences and sorts the results.
message("Generating file summary...")

file_summary <- tibble(FilePath = all_files) %>%
  mutate(
    # basename() gets just the filename from the full path
    FileName = basename(FilePath),
    # Use stringr for a more readable and robust extraction
    Extension = str_extract(FileName, "(?<=\\.)[^.]+$") %>%
      # If no extension is found (returns NA), replace with a descriptor
      replace_na("(no extension)")
  ) %>%
  count(Extension, name = "Count", sort = TRUE)

print("--- Summary of File Extensions ---")
print(file_summary)


# --- 5. WRITE RESULTS TO FILE ---
# Save the summary table to a CSV file in a 'Results/FileCheks_Extensions' directory.

message("Writing results to file...")

# Define the output directory path
output_dir <- file.path(getwd(), "Results", "FileCheks_Extensions")

# Create the directory if it doesn't exist
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Define full output file path
output_file_summary <- file.path(output_dir, paste0("File_Extension_Summary_", Sys.Date(), ".csv"))

# Write the CSV file
write.csv(
  file_summary,
  file = output_file_summary,
  row.names = FALSE
)

message(paste("Summary file created in:", output_dir))
message("Process complete.")