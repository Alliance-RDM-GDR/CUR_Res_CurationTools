#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_xml_Script.R
# Purpose: Batch inspection of XML files.
#          - Checks Well-Formedness and Schema Validity (if XSD present).
#          - Extracts Root Node, Namespaces, and Nesting Depth.
# Usage:   Rscript Inspect_xml_Script.R <target_directory>
# ==============================================================================

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(xml2)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select XML Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_xml")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_xml_Script.R /path/to/xml_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_xml")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting XML analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
xml_files <- list.files(
  path = target_dir,
  pattern = "\\.xml$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

xsd_files <- list.files(
  path = target_dir,
  pattern = "\\.xsd$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(xml_files), "XML files."))
message(paste("Found", length(xsd_files), "XSD Schema files."))

if (length(xml_files) == 0) {
  message("No XML files found. Exiting.")
  quit(status = 0)
}

# 3. Validation Setup ----------------------------------------------------------
active_schema <- NULL
if (length(xsd_files) > 0) {
  message(paste("Using Schema for validation:", basename(xsd_files[1])))
  active_schema <- read_xml(xsd_files[1])
}

# 4. Processing Function -------------------------------------------------------
get_max_depth <- function(node) {
  children <- xml_children(node)
  if (length(children) == 0) return(1)
  return(1 + max(sapply(children, get_max_depth)))
}

process_xml_file <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # A. Parse
    doc <- read_xml(file_path)
    
    # B. Validation
    validity <- "Not Checked (No XSD)"
    if (!is.null(active_schema)) {
      is_valid <- xml_validate(doc, active_schema)
      validity <- if (is_valid) "Valid" else "Invalid"
    }
    
    # C. Structure
    root <- xml_root(doc)
    root_name <- xml_name(root)
    
    ns <- xml_ns(doc)
    ns_str <- if (length(ns) > 0) paste(names(ns), collapse = ", ") else "None"
    
    max_depth <- tryCatch(get_max_depth(root), error = function(e) "Error")
    
    tibble(
      FileName = fname,
      Status = "Well-Formed",
      SchemaValidation = validity,
      RootNode = root_name,
      Namespaces = ns_str,
      MaxDepth = as.character(max_depth),
      DirectChildren = length(xml_children(root))
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname,
      Status = "Parsing Failed",
      SchemaValidation = "Failed",
      RootNode = "Error",
      Namespaces = "",
      MaxDepth = NA,
      DirectChildren = NA
    )
  })
}

# 5. Execution -----------------------------------------------------------------
message("Generating XML Report...")
report <- map_dfr(xml_files, process_xml_file)

# 6. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("XML_Structure_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(report, output_file)
message(paste("✅ Process Complete. Report saved to:", output_file))