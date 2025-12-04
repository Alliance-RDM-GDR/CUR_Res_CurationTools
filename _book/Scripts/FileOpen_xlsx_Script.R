#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
# TITLE: Excel File (.xls, .xlsx) inspector
# DESCRIPTION: Scans a directory for Excel files, then reports on every
#              sheet's name, dimensions, and header content.
# USAGE:
#   Interactive: Source in RStudio -> Select Directory
#   CLI/HPC:     Rscript check_excel.R /path/to/data_folder
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(readxl))
suppressPackageStartupMessages(library(rstudioapi))

# --- 1. GET TARGET DIRECTORY ---
target_dir <- ""
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  target_dir <- rstudioapi::selectDirectory(caption = "Select Excel Directory")
  if (is.null(target_dir)) stop("No directory selected.", call. = FALSE)
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) stop("No path provided. Usage: Rscript check_excel.R <path_to_folder>", call. = FALSE)
  target_dir <- args[1]
}

if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir), call. = FALSE)
message(paste("Analyzing:", target_dir))

# --- 2. FIND FILES ---
excel_files <- list.files(
  path = target_dir,
  pattern = "\\.xlsx?$", # Matches .xls or .xlsx
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(excel_files) == 0) stop("No .xls or .xlsx files found.", call. = FALSE)
message(paste("Found", length(excel_files), "Excel files."))

# --- 3. PROCESS FILES ---
message("Generating structural report...")
all_sheets_summary <- list()

for (file_path in excel_files) {
  file_name <- basename(file_path)
  
  tryCatch({
    sheet_names <- excel_sheets(file_path)
    
    if (length(sheet_names) == 0) {
      all_sheets_summary[[length(all_sheets_summary) + 1]] <- tibble(
        FileName = file_name, SheetName = "(No Sheets Found)", Dimensions = "0 x 0",
        IsLikelyNonTabular = TRUE, HeaderPreview = "(Empty)"
      )
      next
    }
    
    for (sheet_name in sheet_names) {
      tryCatch({
        full_sheet_data <- read_excel(file_path, sheet = sheet_name, .name_repair = "minimal")
        true_dims <- paste(dim(full_sheet_data), collapse = " x ")
        
        header_preview <- read_excel(file_path, sheet = sheet_name, n_max = 5, .name_repair = "minimal")
        col_names <- colnames(header_preview)
        
        is_non_tabular <- any(str_detect(col_names, "^\\.\\.\\.\\d+$")) || length(col_names) <= 1
        header_as_string <- paste(col_names, collapse = " | ")
        
        all_sheets_summary[[length(all_sheets_summary) + 1]] <- tibble(
          FileName = file_name, SheetName = sheet_name, Dimensions = true_dims,
          IsLikelyNonTabular = is_non_tabular, HeaderPreview = header_as_string
        )
      }, error = function(e_sheet) {
        message(paste("Error on sheet:", sheet_name, "in file:", file_name))
        all_sheets_summary[[length(all_sheets_summary) + 1]] <- tibble(
          FileName = file_name, SheetName = sheet_name, Dimensions = "Error",
          IsLikelyNonTabular = TRUE, HeaderPreview = "ERROR: Sheet read failed"
        )
      })
    }
  }, error = function(e_file) {
    message(paste("Error on file:", file_name))
    all_sheets_summary[[length(all_sheets_summary) + 1]] <- tibble(
      FileName = file_name, SheetName = "Error", Dimensions = "Error",
      IsLikelyNonTabular = TRUE, HeaderPreview = "ERROR: File read failed"
    )
  })
}

# --- 4. SAVE REPORT ---
summary_report <- bind_rows(all_sheets_summary)
out_dir <- file.path(getwd(), "Results", "ExcelChecker")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
output_file <- file.path(out_dir, paste0("Excel_Structure_Report_", Sys.Date(), ".csv"))

write.csv(summary_report, file = output_file, row.names = FALSE)

message(paste("Done. Report saved to:", output_file))