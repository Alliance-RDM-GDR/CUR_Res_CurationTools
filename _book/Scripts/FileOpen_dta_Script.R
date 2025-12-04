#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
# TITLE: Stata File (.dta) Inspector
# DESCRIPTION: Scans directory for .dta files and generates a Data Dictionary.
# USAGE:
#   Interactive: Source in RStudio -> Select Directory
#   CLI/HPC:     Rscript check_stata.R /path/to/data_folder
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(rstudioapi))

# --- 1. GET TARGET DIRECTORY ---
target_dir <- ""
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  target_dir <- rstudioapi::selectDirectory(caption = "Select Stata Directory")
  if (is.null(target_dir)) stop("No directory selected.", call. = FALSE)
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) stop("No path provided. Usage: Rscript check_stata.R <path>", call. = FALSE)
  target_dir <- args[1]
}

if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir), call. = FALSE)
message(paste("Analyzing:", target_dir))

# --- 2. FIND FILES ---
dta_files <- list.files(target_dir, pattern = "\\.dta$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
if (length(dta_files) == 0) stop("No .dta files found.", call. = FALSE)
message(paste("Found", length(dta_files), "Stata files."))

# --- 3. EXTRACT METADATA ---
message("Generating Data Dictionary...")

report <- purrr::map_dfr(dta_files, function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # Read header only
    data <- read_dta(file_path, n_max = 100)
    
    purrr::map_dfr(names(data), function(var) {
      col <- data[[var]]
      
      # Labels
      lbl <- attr(col, "label", exact = TRUE)
      if (is.null(lbl)) lbl <- "(No Label)"
      
      # Values
      val_lbls <- attr(col, "labels", exact = TRUE)
      val_str <- if (!is.null(val_lbls)) paste(val_lbls, names(val_lbls), sep="=", collapse="; ") else ""
      
      tibble(
        FileName = fname,
        VariableName = var,
        VariableLabel = lbl,
        DataType = class(col)[1],
        ValueLabels = substr(val_str, 1, 100)
      )
    })
  }, error = function(e) {
    tibble(FileName = fname, VariableName = "ERROR", VariableLabel = e$message, DataType = "Error", ValueLabels = "")
  })
})

# --- 4. SAVE RESULTS ---
out_dir <- file.path(getwd(), "Results", "FileOpen_dta")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_file <- file.path(out_dir, paste0("Stata_Dictionary_", Sys.Date(), ".csv"))

write.csv(report, out_file, row.names = FALSE)
message(paste("Done. Dictionary saved to:", out_file))