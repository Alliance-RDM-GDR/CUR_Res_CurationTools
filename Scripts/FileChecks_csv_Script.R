#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
#
# TITLE: Automated CSV File Checker
# AUTHOR: Natalie Williams
# DATE: 2025-11-13
#
# DESCRIPTION:
# This script provides a standardized procedure for checking and summarizing
# the contents of multiple .csv files within a directory. 
# It generates two reports: a long-format metadata summary and a
# wide-format column comparison. 
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
#      Rscript check_csvs.R /path/to/your/data_folder
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
    stop("No directory path provided. Usage: Rscript check_csvs.R /path/to/folder", call. = FALSE)
  } else {
    target_dir <- args[1]
    if (!dir.exists(target_dir)) {
      stop(paste("Directory does not exist:", target_dir), call. = FALSE)
    }
  }
}

message(paste("Using directory:", target_dir))


# --- 3. FIND CSV FILES ---
# Searches the target directory and all subdirectories
# for files ending in .csv. 

message("Finding CSV files...")
csv.files <- list.files(
  path = target_dir,
  pattern = "*.csv",
  recursive = TRUE,
  full.names = TRUE # Use full paths
)

if (length(csv.files) == 0) {
  stop("No .csv files found in the specified directory.", call. = FALSE)
}

message(paste("Found", length(csv.files), "CSV files."))


# --- 4. INITIALIZE SUMMARY TABLE ---
# Create an empty data frame to store results. 

csv.summ <- data.frame(
  file.name = character(),
  column.name = character(),
  column.type = character(),
  rows = integer(),
  min = character(),
  mean = character(),
  med = character(),
  max = character(),
  NAs = character()
)


# --- 5. PROCESS EACH FILE ---
# Loop through each file, extract metadata and stats, and handle errors. 

message("Processing files...")

for (i in csv.files) {
  # Use tryCatch to skip corrupt/unreadable files. 
  tryCatch({
    
    # Read the file
    tmp <- read.csv(i)
    
    # Get basic file metadata. 
    tmp.meta <- data.frame(
      file.name = basename(i),
      column.name = colnames(tmp),
      column.type = sapply(tmp, class),
      rows = nrow(tmp)
    )
    
    # Calculate descriptive stats. 
    tmp.stat <- tmp %>%
      summarise(
        across(
          .cols = everything(),
          .fns = list(
            min = ~min(.x, na.rm = TRUE),
            mean = ~mean(.x, na.rm = TRUE),
            med = ~median(.x, na.rm = TRUE),
            max = ~max(.x, na.rm = TRUE),
            NAs = ~sum(is.na(.x))
          ),
          .names = "{.col}|{.fn}"
        )
      ) %>%
      mutate(
        across(everything(), as.character)
      ) %>%
      # Pivot to long format.
      pivot_longer(
        cols = everything(),
        names_to = c("column.name", ".value"),
        names_pattern = "(.*)\\|(.*)"
      )
    
    # Join metadata and stats
    tmp.meta <- full_join(tmp.meta, tmp.stat, by = "column.name")
    
    # Add to the main summary table
    csv.summ <- bind_rows(csv.summ, tmp.meta)
    
  }, error = function(e) {
    # If an error occurs, print a message and skip the file. 
    message(paste("--- ERROR --- Failed to process file:", i))
    message(paste("    Specific error message:", e$message))
    message("    Skipping this file and continuing.\n")
  })
}

# Clean up temporary variables
rm(tmp, tmp.stat, tmp.meta, i)


# --- 6. CREATE COMPARISON TABLE ---
# Create a wide-format table to compare column types across files. 
message("Creating comparison table...")

col.compare <- csv.summ %>%
  pivot_wider(
    id_cols = "file.name",
    names_from = "column.name",
    values_from = "column.type",
    # Handles duplicate column names within a file
    values_fn = ~paste(., collapse = ", ")
  )


# --- 7. WRITE RESULTS TO FILE ---
# Save the summary tables to CSV files in a 'Results/FileChecks_csv' directory. 

message("Writing results to file...")

# Define the output directory path
output_dir <- file.path(getwd(), "Results", "FileChecks_csv")

# Create the directory if it doesn't exist
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Define full output file paths
output_file_meta <- file.path(output_dir, "MetaData_CSV.csv")
output_file_cols <- file.path(output_dir, "ColumnCheck_CSV.csv")

# Write the CSV files
write.csv(csv.summ, file = output_file_meta, row.names = FALSE)
write.csv(col.compare, file = output_file_cols, row.names = FALSE)

message(paste("Summary files created in:", output_dir))
message("Process complete.")