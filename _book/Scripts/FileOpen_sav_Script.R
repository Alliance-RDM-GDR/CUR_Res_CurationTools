#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
#
# TITLE: SPSS (.sav) files inspector
# AUTHOR: Daniel Manrique-Castano
# DATE: 2025-12-01
#
# DESCRIPTION:
# This script inspects all SPSS files within a given directory.
# For each .sav file, it lists a data dictionary with all the variables available.
#
# USAGE:
#
# 1. INTERACTIVE (RStudio):
#    - Source this script. A dialog box will appear to select a DIRECTORY.
#
# 2. NON-INTERACTIVE (HPC / Command-Line):
#    - Rscript FileOpen_sav_Script.R /path/to/your/folder_with_savs
#
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(rstudioapi))

# 1. GET DIRECTORY
target_dir <- ""
if (interactive()) {
  target_dir <- rstudioapi::selectDirectory(caption = "Select SPSS Directory")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) stop("Usage: Rscript check_spss.R <path>")
  target_dir <- args[1]
}
if (!dir.exists(target_dir) || is.null(target_dir)) stop("Directory not found.")

# 2. FIND FILES
files <- list.files(target_dir, pattern = "\\.sav$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
message(paste("Found", length(files), "SPSS files."))

# 3. PROCESS
message("Generating dictionary...")
report <- purrr::map_dfr(files, function(file_path) {
  fname <- basename(file_path)
  tryCatch({
    data <- read_sav(file_path, n_max = 100)
    purrr::map_dfr(names(data), function(var) {
      col <- data[[var]]
      lbl <- attr(col, "label", exact = TRUE)
      if (is.null(lbl)) lbl <- "(No Label)"
      val_lbls <- attr(col, "labels", exact = TRUE)
      val_str <- if (!is.null(val_lbls)) paste(names(val_lbls), val_lbls, sep="=", collapse="; ") else ""
      
      tibble(FileName = fname, VariableName = var, VariableLabel = lbl, 
             DataType = class(col)[1], ValueLabels = substr(val_str, 1, 100))
    })
  }, error = function(e) {
    tibble(FileName = fname, VariableName = "ERROR", VariableLabel = e$message)
  })
})

# 4. SAVE
out_dir <- file.path(getwd(), "Results", "FileOpen_sav")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(report, file.path(out_dir, paste0("Sav_Dictionary_", Sys.Date(), ".csv")), row.names = FALSE)
message("Done.")