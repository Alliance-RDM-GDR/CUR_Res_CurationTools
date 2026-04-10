#!/usr/bin/env Rscript

# ==============================================================================
# Script: OCR_Curator_Script_Robust.R
# Purpose: Hybrid Text Extraction (Layout-Aware Digital + Google Cloud OCR)
#          Saves individual .txt sidecar files and a CSV summary.
# Usage:   Rscript OCR_Curator_Script_Robust.R /path/to/documents
# NOTE: Please provide your specific my_proj_id and my_proc_id 
#       (see the associated Inspect_OCR_Notebook.qmd for details)

# ==============================================================================

# 1. Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript OCR_Curator_Script_Robust.R /path/to/documents", call. = FALSE)
}
target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(daiR)
  library(pdftools)
  library(httr)
  library(stringr)
})

# --- CONFIGURATION (Based on your Project Details) ---
my_proj_id <- "YOUR PROJECT ID"
my_proc_id <- "YOUR PROCESS ID"
my_loc     <- "us"
key_path   <- "service-account.json"

# --- AUTHENTICATION ---
if (file.exists(key_path)) {
  Sys.setenv(GCS_AUTH_FILE = key_path)
  dai_auth()
  message("✅ Auth: Credentials loaded successfully.")
} else {
  stop("FATAL: 'service-account.json' not found in the script directory.")
}

# 2. Define Processing Functions -----------------------------------------------

# Helper: Layout-Aware Digital Extraction
# Uses pdf_data() to reconstruct text spatially (preserves columns/tables)
extract_digital_robust <- function(fp) {
  tryCatch({
    data_pages <- pdftools::pdf_data(fp)
    
    # Reconstruct text page by page
    full_text <- map_chr(data_pages, function(page_df) {
      if (nrow(page_df) == 0) return("")
      # Sort by Y (line) then X (position) to ensure correct reading order
      page_df %>%
        arrange(y, x) %>%
        group_by(y) %>%
        summarise(line_text = paste(text, collapse = " "), .groups = "drop") %>%
        pull(line_text) %>%
        paste(collapse = "\n")
    }) %>% paste(collapse = "\n\n")
    
    return(full_text)
  }, error = function(e) return(""))
}

# Main Processing Logic (Hybrid)
process_doc_robust <- function(fp) {
  
  # --- PATH A: Local Digital Extraction ---
  if (str_detect(fp, "(?i)\\.pdf$")) {
    digital_text <- extract_digital_robust(fp)
    
    # Validation: If we found substantial text (>500 chars), we accept it.
    if (nchar(digital_text) > 500) {
      return(tibble(
        file_path = fp, 
        extracted_text = digital_text,
        ocr_confidence = 1.0, 
        source = "LOCAL_PDF_LAYOUT", 
        status = "SUCCESS"
      ))
    }
  }
  
  # --- PATH B: Google Cloud OCR (Fallback) ---
  tryCatch({
    # API Call
    raw_response <- dai_sync(fp, proc_id = my_proc_id, proj_id = my_proj_id, loc = my_loc)
    
    # Parse Response
    data <- httr::content(raw_response, as = "parsed")
    
    # Extract Text
    txt <- data$document$text
    if(is.null(txt)) txt <- ""
    
    # Calculate Confidence
    confs <- tryCatch({
      data$document$pages %>% map(~.x$blocks) %>% flatten() %>% map(~.x$layout$confidence) %>% unlist()
    }, error=function(e) NULL)
    
    conf <- if(is.numeric(confs) && length(confs)>0) mean(confs, na.rm=TRUE) else 0
    
    tibble(
      file_path = fp, 
      extracted_text = txt, 
      ocr_confidence = round(conf, 4), 
      source = "GOOGLE_DOC_AI", 
      status = "SUCCESS"
    )
  }, error = function(e) {
    tibble(
      file_path = fp, 
      extracted_text = NA_character_, 
      ocr_confidence = NA_real_, 
      source = "FAILED", 
      status = paste("ERROR:", e$message)
    )
  })
}

# 3. Execution Phase -----------------------------------------------------------
message(paste("Starting analysis on:", target_dir))

# A. Inventory
files <- list.files(target_dir, pattern = "\\.(pdf|jpg|png|tif)$", full.names = TRUE, recursive = TRUE)

inventory <- tibble(file_path = files) %>%
  mutate(
    filename = basename(file_path),
    filesize_mb = file.size(file_path) / 1024^2,
    is_large = filesize_mb > 20 # Limit for Sync API
  )

message(paste("Found", nrow(inventory), "files. Processing..."))

# B. Run Processing Loop
# We filter out large files to avoid API errors
results_raw <- inventory %>%
  filter(!is_large) %>%
  pull(file_path) %>%
  map_dfr(process_doc_robust)

# C. Merge & Curate
curated_data <- inventory %>%
  left_join(results_raw, by = "file_path") %>%
  mutate(
    # Curation Flags
    flag_low_conf = ifelse(ocr_confidence < 0.85, "LOW_CONFIDENCE", NA),
    flag_pii      = ifelse(str_detect(extracted_text, "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+"), "POSSIBLE_PII", NA),
    flag_empty    = ifelse(nchar(extracted_text) < 10, "NO_TEXT_EXTRACTED", NA)
  ) %>%
  unite("curation_flags", starts_with("flag_"), sep = "; ", na.rm = TRUE, remove = FALSE)

# 4. Export Phase --------------------------------------------------------------
output_dir <- "Results/OCR_Scan"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# A. Save Sidecar Text Files (.txt)
message("Saving individual text files...")
curated_data %>%
  filter(!is.na(extracted_text) & extracted_text != "") %>%
  pwalk(function(filename, extracted_text, ...) {
    txt_name <- paste0(output_dir, "/", filename, ".txt")
    writeLines(extracted_text, txt_name)
  })

# B. Save Metadata CSV (excluding full text)
csv_file <- paste0(output_dir, "/Curation_Report_OCR_", format(Sys.Date(), "%Y%m%d"), ".csv")

final_export <- curated_data %>%
  select(filename, ocr_confidence, source, curation_flags, status)

write.csv(final_export, csv_file, row.names = FALSE)

message(paste("✅ Process Complete."))
message(paste("   Metadata saved to:", csv_file))
message(paste("   Text files saved to:", output_dir))