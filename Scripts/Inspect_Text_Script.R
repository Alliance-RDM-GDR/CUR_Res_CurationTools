#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Text_Script.R
# Purpose: Batch inspection of Text/Markdown files.
#          - Detects Encoding & Byte Order Mark (BOM)
#          - Identifies Line Endings (CRLF vs LF)
#          - Extracts Links (for validation) and Emails (PII Check)
# Usage:   Rscript Inspect_Text_Script.R <target_directory>
# ==============================================================================

# 1. Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_Text_Script.R /path/to/text_files", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(stringr)
})

message(paste("Starting Text analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
text_files <- list.files(
  path = target_dir,
  pattern = "\\.(txt|md|csv|rmd)$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(text_files), "Text/Markdown files."))

if (length(text_files) == 0) {
  message("No text files found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function -------------------------------------------------------
url_pattern <- "http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+"
email_pattern <- "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"

inspect_text_file <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # A. BOM Detection
    con <- file(file_path, "rb")
    bytes <- readBin(con, "raw", n = 4)
    close(con)
    has_bom <- identical(bytes[1:3], as.raw(c(0xef, 0xbb, 0xbf)))
    
    # B. Encoding Guess
    guess <- readr::guess_encoding(file_path, n_max = 1000)[1, ]
    encoding <- if (!is.na(guess$encoding)) guess$encoding else "Unknown"
    confidence <- if (!is.na(guess$confidence)) guess$confidence else 0
    
    # C. Content Analysis
    content_lines <- readLines(file_path, warn = FALSE)
    full_text <- paste(content_lines, collapse = "\n")
    
    # D. Line Ending Detection (requires raw read)
    raw_text <- readChar(file_path, nchars = 2000, useBytes = TRUE)
    eol_type <- "Unknown"
    if (length(raw_text) > 0) {
      if (grepl("\r\n", raw_text)) {
        eol_type <- "Windows (CRLF)"
      } else if (grepl("\n", raw_text)) {
        eol_type <- "Unix (LF)"
      } else if (grepl("\r", raw_text)) {
        eol_type <- "Classic Mac (CR)"
      }
    }
    
    # E. Artifact Extraction
    urls <- str_extract_all(full_text, url_pattern)[[1]]
    emails <- str_extract_all(full_text, email_pattern)[[1]]
    example_links <- paste(head(unique(urls), 3), collapse = ", ")
    
    tibble(
      FileName = fname,
      Encoding = encoding,
      Confidence = confidence,
      HasBOM = has_bom,
      LineEndings = eol_type,
      LineCount = length(content_lines),
      URL_Count = length(urls),
      Email_Count = length(unique(emails)),
      Example_Links = substr(example_links, 1, 100),
      Status = "Success"
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname, Encoding = NA, Confidence = NA, HasBOM = NA,
      LineEndings = NA, LineCount = NA, URL_Count = NA, Email_Count = NA,
      Example_Links = NA, Status = paste("Failed:", e$message)
    )
  })
}

# 4. Execution -----------------------------------------------------------------
message("Generating Text Report...")
report <- map_dfr(text_files, inspect_text_file)

# 5. Export --------------------------------------------------------------------
output_dir <- "Results/Inspect_Text"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, paste0("Text_Report_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write.csv(report, output_file, row.names = FALSE)
message(paste("✅ Process Complete. Report saved to:", output_file))