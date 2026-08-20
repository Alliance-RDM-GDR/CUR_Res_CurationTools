#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_PDF_Script.R
# Purpose: Batch inspection of PDF files for archival quality.
#          Checks: Metadata (Author/Title), Encryption, and Text Accessibility.
# Usage:   Rscript Inspect_PDF_Script.R <target_directory>
# ==============================================================================

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(pdftools)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select PDF Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_pdf")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_PDF_Script.R /path/to/pdf_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_pdf")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting PDF analysis on:", target_dir))

# 2. Inventory Files -----------------------------------------------------------
pdf_files <- list.files(
  path = target_dir, 
  pattern = "\\.pdf$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(pdf_files), "PDF files."))

if (length(pdf_files) == 0) {
  message("No PDF files found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function -------------------------------------------------------
inspect_pdf <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # A. Metadata & Security
    info <- pdftools::pdf_info(file_path)
    is_encrypted <- isTRUE(info$encrypted)
    
    # B. Text Extraction
    # Wrap in tryCatch because encrypted files might fail here
    first_page_text <- tryCatch(pdftools::pdf_text(file_path)[1], error = function(e) "")
    if(is.na(first_page_text) || is.null(first_page_text)) first_page_text <- ""
    
    char_count <- nchar(trimws(first_page_text))
    has_text <- char_count > 10 
    
    # C. Fonts
    fonts <- tryCatch(pdftools::pdf_fonts(file_path), error = function(e) NULL)
    font_names <- if (!is.null(fonts)) paste(head(unique(fonts$name), 5), collapse = ", ") else "Unknown"
    
    # Helper for metadata
    get_meta <- function(x) {
      if (is.null(x) || length(x) == 0 || x == "") return("Unknown")
      return(as.character(x))
    }
    
    tibble(
      FileName = fname,
      Pages = as.integer(info$pages),
      Encrypted = as.logical(is_encrypted),
      Author = get_meta(info$keys$Author),
      Title = get_meta(info$keys$Title),
      Creator = get_meta(info$keys$Creator),
      Created = as.character(info$created),
      HasText = as.logical(has_text),
      FirstPageChars = as.integer(char_count),
      Fonts = as.character(font_names),
      Status = "Success"
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname,
      Pages = as.integer(NA),
      Encrypted = as.logical(NA),
      Author = as.character(NA),
      Title = as.character(NA),
      Creator = as.character(NA),
      Created = as.character(NA),
      HasText = as.logical(NA),
      FirstPageChars = as.integer(NA),
      Fonts = as.character(NA),
      Status = paste("Failed:", e$message)
    )
  })
}

# 4. Execution Loop ------------------------------------------------------------
message("Analyzing PDFs...")
# Using lapply then bind_rows is safer for debugging than map_dfr in scripts
results_list <- lapply(pdf_files, inspect_pdf)
report <- bind_rows(results_list)

# 5. Export Results ------------------------------------------------------------
output_file <- file.path(output_dir, paste0("PDF_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(report, output_file)

message(paste("✅ Process Complete."))
message(paste("   Analyzed:", nrow(report), "files"))
message(paste("   Report saved to:", output_file))