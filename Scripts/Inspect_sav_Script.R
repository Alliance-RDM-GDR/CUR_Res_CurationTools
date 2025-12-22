#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_sav_Script.R
# Purpose: Batch inspection of SPSS (.sav) files for archival quality.
#          - Extracts Variable Labels and Value Labels (Codebook).
#          - Inventories User-Defined Missing Values (Critical for preservation).
#          - Checks for potential Character Encoding issues (Mojibake).
# Usage:   Rscript Inspect_sav_Script.R <target_directory>
# ==============================================================================

# 1. Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_sav_Script.R /path/to/spss_files", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(stringr)
})

message(paste("Starting SPSS analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
spss_files <- list.files(
  path = target_dir,
  pattern = "\\.sav$|\\.zsav$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(spss_files), "SPSS files."))

if (length(spss_files) == 0) {
  message("No SPSS files found. Exiting.")
  quit(status = 0)
}

# 3. Helper Functions ----------------------------------------------------------

# Helper: Encoding Check (Flag Non-ASCII characters)
check_encoding <- function(col) {
  # Check if variable is character or factor
  if (is.character(col) || is.factor(col)) {
    txt <- as.character(col)
    # Check for any character outside standard ASCII range (0-127)
    has_special <- any(str_detect(txt, "[^\\x00-\\x7F]"), na.rm = TRUE)
    return(if (has_special) "Contains Special/Non-ASCII" else "ASCII")
  }
  return("N/A")
}

# Helper: Extract User-Defined Missing Values
get_na_values <- function(col) {
  # 'haven' stores these in attributes
  na_vals <- attr(col, "na_values", exact = TRUE)
  na_range <- attr(col, "na_range", exact = TRUE)
  
  res <- ""
  if (!is.null(na_vals)) res <- paste(na_vals, collapse = ", ")
  if (!is.null(na_range)) {
    range_str <- paste0(na_range[1], " to ", na_range[2])
    res <- if(res == "") range_str else paste(res, range_str, sep = "; ")
  }
  return(if (res == "") "None" else res)
}

# 4. Processing Function -------------------------------------------------------
process_spss_file <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # Read header only (first 100 rows) for speed/memory efficiency
    data <- read_sav(file_path, n_max = 100)
    
    purrr::map_dfr(names(data), function(var) {
      col <- data[[var]]
      
      # 1. Variable Label
      lbl <- attr(col, "label", exact = TRUE)
      if (is.null(lbl)) lbl <- "(No Label)"
      
      # 2. Value Labels
      val_lbls <- attr(col, "labels", exact = TRUE)
      val_str <- if (!is.null(val_lbls)) paste(val_lbls, names(val_lbls), sep="=", collapse="; ") else ""
      
      # 3. Measurement Level (Implicit via class)
      dtype <- class(col)[1]
      
      # 4. Construct Row
      tibble(
        FileName = fname,
        VariableName = var,
        VariableLabel = lbl,
        DataType = dtype,
        ValueLabels = substr(val_str, 1, 100), # Truncate for readability
        MissingValues = get_na_values(col),
        EncodingCheck = check_encoding(col),
        Status = "Success"
      )
    })
    
  }, error = function(e) {
    # Error Handling
    tibble(
      FileName = fname, VariableName = "ERROR", VariableLabel = e$message,
      DataType = "Error", ValueLabels = "", MissingValues = "", 
      EncodingCheck = "", Status = "Failed"
    )
  })
}

# 5. Execution -----------------------------------------------------------------
message("Generating Data Dictionary...")
# Use map_dfr for clean binding of results
report <- map_dfr(spss_files, process_spss_file)

# 6. Export --------------------------------------------------------------------
output_dir <- "Results/Inspect_sav"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, paste0("SPSS_Dictionary_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write.csv(report, output_file, row.names = FALSE)

message(paste("✅ Process Complete."))
message(paste("   Analyzed:", length(unique(report$FileName)), "files"))
message(paste("   Report saved to:", output_file))