#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_sas7bdat_Script.R
# Purpose: Batch inspection of SAS files (.sas7bdat, .xpt).
#          - Detects Format (SAS7BDAT vs XPORT vs CPORT)
#          - Extracts Variable Labels and Value Labels
#          - Checks for Catalog files (.sas7bcat)
# Usage:   Rscript Inspect_sas7bdat_Script.R <target_directory>
# ==============================================================================

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(haven)
  library(sas7bdat)
  library(stringr)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select SAS Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_sas7bdat")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_sas7bdat_Script.R /path/to/sas_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_sas7bdat")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting SAS analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
sas_files <- list.files(
  path = target_dir,
  pattern = "\\.sas7bdat$|\\.xpt$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

cat_files <- list.files(
  path = target_dir,
  pattern = "\\.sas7bcat$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(sas_files), "SAS Data files."))
message(paste("Found", length(cat_files), "SAS Catalog files."))

if (length(sas_files) == 0) {
  message("No SAS data files found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function (Strategy 0-2) ----------------------------------------
check_encoding <- function(col) {
  if (is.character(col)) {
    has_special <- any(str_detect(col, "[^\\x00-\\x7F]"), na.rm = TRUE)
    return(if (has_special) "Contains Special/Non-ASCII" else "ASCII")
  }
  return("N/A")
}

process_sas_file <- function(file_path) {
  fname <- basename(file_path)
  
  # STRATEGY 0: DETECT FORMAT (Header Check)
  header_check <- tryCatch({
    con <- file(file_path, "rb")
    on.exit(close(con))
    raw_header <- readBin(con, "raw", n = 80)
    rawToChar(raw_header)
  }, error = function(e) "")
  
  is_transport <- grepl("SAS FILE", header_check, fixed = TRUE)
  
  if (is_transport) {
    # STRATEGY 1A: HAVEN (XPORT)
    tryCatch({
      data <- read_xpt(file_path, n_max = 100)
      
      purrr::map_dfr(names(data), function(var) {
        col <- data[[var]]
        lbl <- attr(col, "label", exact = TRUE)
        if (is.null(lbl)) lbl <- "(No Label)"
        val_lbls <- attr(col, "labels", exact = TRUE)
        val_str <- if (!is.null(val_lbls)) paste(val_lbls, names(val_lbls), sep="=", collapse="; ") else ""
        
        tibble(
          FileName = fname, VariableName = var, VariableLabel = lbl, 
          DataType = class(col)[1], ValueLabels = substr(val_str, 1, 100),
          EncodingCheck = check_encoding(col),
          Method = "Haven (XPORT)"
        )
      })
    }, error = function(e_xpt) {
      tibble(
        FileName = fname, VariableName = "ERROR", 
        VariableLabel = paste("Failed XPORT/CPORT read:", e_xpt$message), 
        DataType = "Error", ValueLabels = "", EncodingCheck = "NA",
        Method = "Failed (XPORT/CPORT)"
      )
    })
    
  } else {
    # STRATEGY 1B: HAVEN (SAS7BDAT)
    tryCatch({
      data <- read_sas(file_path, n_max = 100)
      
      purrr::map_dfr(names(data), function(var) {
        col <- data[[var]]
        lbl <- attr(col, "label", exact = TRUE)
        if (is.null(lbl)) lbl <- "(No Label)"
        val_lbls <- attr(col, "labels", exact = TRUE)
        val_str <- if (!is.null(val_lbls)) paste(val_lbls, names(val_lbls), sep="=", collapse="; ") else ""
        
        tibble(
          FileName = fname, VariableName = var, VariableLabel = lbl, 
          DataType = class(col)[1], ValueLabels = substr(val_str, 1, 100),
          EncodingCheck = check_encoding(col),
          Method = "Haven"
        )
      })
      
    }, error = function(e_haven) {
      # STRATEGY 2: SAS7BDAT (Fallback)
      tryCatch({
        data_fallback <- read.sas7bdat(file_path, debug = FALSE) 
        col_info <- attr(data_fallback, "column.info")
        
        if (!is.null(col_info)) {
          purrr::map_dfr(col_info, function(col) {
            tibble(
              FileName = fname, VariableName = col$name,
              VariableLabel = if(!is.null(col$label) && col$label != "") col$label else "(No Label)",
              DataType = col$type, ValueLabels = "(Check Catalog)", 
              EncodingCheck = "Unknown", Method = "Fallback (sas7bdat)"
            )
          })
        } else {
          purrr::map_dfr(names(data_fallback), function(var) {
            tibble(FileName = fname, VariableName = var, VariableLabel = "-", 
                   DataType = "-", ValueLabels = "-", EncodingCheck = "Unknown", Method = "Fallback (Basic)")
          })
        }
      }, error = function(e_fallback) {
        tibble(
          FileName = fname, VariableName = "ERROR", 
          VariableLabel = paste("Haven:", e_haven$message, "| Fallback:", e_fallback$message), 
          DataType = "Error", ValueLabels = "", EncodingCheck = "NA", Method = "Failed"
        )
      })
    })
  }
}

# 4. Execution -----------------------------------------------------------------
message("Generating Data Dictionary...")
report <- map_dfr(sas_files, process_sas_file)

# 5. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("SAS_Dictionary_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(report, output_file)
message(paste("✅ Process Complete. Report saved to:", output_file))