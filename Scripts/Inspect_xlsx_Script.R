#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_xlsx_Script.R
# Purpose: Batch inspection of Excel files (.xls, .xlsx, .xlsm).
#          - Structure Scan: Hidden sheets, Macros, File Format.
#          - Content Preview: Dimensions, Headers, Tabular Viability.
# Usage:   Rscript Inspect_xlsx_Script.R <target_directory>
# ==============================================================================

# 1. Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_xlsx_Script.R /path/to/excel_files", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
  library(tidyxl)
})

message(paste("Starting Excel analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
excel_files <- list.files(
  path = target_dir,
  pattern = "\\.xls[xmb]?$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(excel_files), "Excel files."))

if (length(excel_files) == 0) {
  message("No Excel files found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function -------------------------------------------------------
analyze_structure <- function(fp) {
  is_modern <- grepl("\\.xlsx$|\\.xlsm$", fp, ignore.case = TRUE)
  is_macro  <- grepl("\\.xlsm$", fp, ignore.case = TRUE)
  
  hidden_sheets <- "Unknown (Legacy)"
  
  if (is_modern) {
    tryCatch({
      # tidyxl allows us to see sheet state (visible/hidden)
      sheet_meta <- tidyxl::xlsx_sheet_names(fp)
      hidden_count <- sum(sheet_meta$state != "visible")
      hidden_sheets <- if (hidden_count > 0) paste0(hidden_count, " Hidden") else "None"
    }, error = function(e) {
      hidden_sheets <- "Scan Failed"
    })
  }
  
  return(list(
    Macros = is_macro,
    Hidden = hidden_sheets,
    Format = if (is_modern) "XML (Modern)" else "Binary (Legacy)"
  ))
}

process_excel_file <- function(file_path) {
  file_name <- basename(file_path)
  
  # A. Structure Scan
  struct <- analyze_structure(file_path)
  
  results <- list()
  
  tryCatch({
    sheet_names <- readxl::excel_sheets(file_path)
    
    if (length(sheet_names) == 0) {
      return(tibble(
        FileName = file_name, SheetName = "(No Sheets)", Dimensions = "0 x 0",
        HeaderPreview = "(Empty)", IsMacro = struct$Macros, 
        HiddenSheets = struct$Hidden, Format = struct$Format, 
        LikelyNonTabular = TRUE, Status = "Empty"
      ))
    }
    
    # B. Content Scan
    for (sheet in sheet_names) {
      tryCatch({
        full_data <- suppressMessages(read_excel(file_path, sheet = sheet, .name_repair = "minimal"))
        dims <- paste(dim(full_data), collapse = " x ")
        
        preview <- suppressMessages(read_excel(file_path, sheet = sheet, n_max = 5, .name_repair = "minimal"))
        col_names <- colnames(preview)
        
        # Check for "...1" default names or single column
        is_messy <- any(grepl("^\\.\\.\\.\\d+$", col_names)) || length(col_names) <= 1
        
        header_str <- paste(head(col_names, 5), collapse = " | ")
        if (length(col_names) > 5) header_str <- paste(header_str, "...")
        
        results[[length(results) + 1]] <- tibble(
          FileName = file_name,
          SheetName = sheet,
          Dimensions = dims,
          HeaderPreview = header_str,
          IsMacro = struct$Macros,
          HiddenSheets = struct$Hidden,
          Format = struct$Format,
          LikelyNonTabular = is_messy,
          Status = "Success"
        )
      }, error = function(e) {
        results[[length(results) + 1]] <- tibble(
          FileName = file_name, SheetName = sheet, Dimensions = "Error",
          HeaderPreview = e$message, IsMacro = struct$Macros, 
          HiddenSheets = struct$Hidden, Format = struct$Format, 
          LikelyNonTabular = TRUE, Status = "Read Failed"
        )
      })
    }
    bind_rows(results)
    
  }, error = function(e) {
    tibble(
      FileName = file_name, SheetName = "Error", Dimensions = "Error",
      HeaderPreview = e$message, IsMacro = struct$Macros, 
      HiddenSheets = struct$Hidden, Format = struct$Format, 
      LikelyNonTabular = TRUE, Status = "File Failed"
    )
  })
}

# 4. Execution -----------------------------------------------------------------
message("Generating Excel Structure Report...")
report <- map_dfr(excel_files, process_excel_file)

# 5. Export --------------------------------------------------------------------
output_dir <- "Results/Inspect_xlsx"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, paste0("Excel_Structure_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write.csv(report, output_file, row.names = FALSE)
message(paste("✅ Process Complete. Report saved to:", output_file))