#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_ipynb_Script.R
# Purpose: Batch inspection of Jupyter Notebooks (.ipynb) for archival quality.
#          Checks JSON validity, documentation ratio, metadata, and dependencies.
# Usage:   Rscript Inspect_ipynb_Script.R <target_directory>
# ==============================================================================

# 1. Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_ipynb_Script.R /path/to/notebooks", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
  library(stringr)
})

message(paste("Starting analysis on:", target_dir))

# 2. Find Files ----------------------------------------------------------------
ipynb_files <- list.files(
  path = target_dir,
  pattern = "\\.ipynb$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(ipynb_files), "Jupyter Notebook files."))

if (length(ipynb_files) == 0) {
  message("No notebooks found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function -------------------------------------------------------

# Regex for imports
import_pattern_py <- "^\\s*(?:import|from)\\s+([a-zA-Z0-9_\\.]+)"
import_pattern_r <- "(?:library|require|p_load)\\s*\\(\\s*[\"']?([a-zA-Z0-9\\.]+)[\"']?\\s*\\)"

process_notebook <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # Read JSON
    nb_json <- jsonlite::fromJSON(file_path, flatten = FALSE)
    
    if (!is.list(nb_json)) {
      stop("Parsed content is not a JSON object")
    }
    
    # --- Metadata ---
    metadata <- nb_json$metadata
    if (is.null(metadata) || !is.list(metadata)) {
      display_name <- "Unknown"
      language <- "Unknown"
    } else {
      kernelspec <- metadata$kernelspec
      if (!is.null(kernelspec) && is.list(kernelspec)) {
        display_name <- if(!is.null(kernelspec$display_name)) kernelspec$display_name else "Unknown"
        language <- if(!is.null(kernelspec$language)) kernelspec$language else "Unknown"
      } else {
        display_name <- "Unknown"
        language <- "Unknown"
      }
    }
    
    format_version <- paste(nb_json$nbformat, nb_json$nbformat_minor, sep=".")
    
    # --- Cell Analysis ---
    cells <- nb_json$cells
    if (is.null(cells) || length(cells) == 0) {
      return(tibble(
        FileName = fname, Language = language, Kernel = display_name, NbFormat = format_version,
        TotalCells = 0, MarkdownCells = 0, CodeCells = 0, doc_ratio = 0,
        HasOutputs = FALSE, ErrorOutputs = 0, ExecOrderLinear = TRUE,
        Libraries = "", Status = "Empty"
      ))
    }
    
    num_cells <- nrow(cells)
    markdown_cells <- sum(cells$cell_type == "markdown")
    code_cells_df <- cells[cells$cell_type == "code", ]
    num_code_cells <- nrow(code_cells_df)
    
    # --- Code Deep Dive ---
    has_output <- FALSE
    error_count <- 0
    exec_order_linear <- TRUE
    detected_libs <- character(0)
    
    if (num_code_cells > 0) {
      # Outputs
      if (!is.null(code_cells_df$outputs)) {
        has_output <- sum(sapply(code_cells_df$outputs, length) > 0) > 0
        all_outputs <- unlist(code_cells_df$outputs, recursive = FALSE)
        if (length(all_outputs) > 0) {
          output_types <- unlist(lapply(all_outputs, function(x) {
            if (is.list(x)) return(x$output_type) else return(NA)
          }))
          error_count <- sum(output_types == "error", na.rm = TRUE)
        }
      }
      
      # Execution Order
      exec_counts <- unlist(code_cells_df$execution_count)
      if (!is.null(exec_counts)) {
        valid_counts <- exec_counts[!is.na(exec_counts)]
        if (length(valid_counts) > 1) {
          exec_order_linear <- !is.unsorted(valid_counts)
        }
      }
      
      # Dependencies
      all_lines <- unlist(code_cells_df$source)
      if (length(all_lines) > 0) {
        if (tolower(language) == "python") {
          matches <- str_match(all_lines, import_pattern_py)
          detected_libs <- unique(matches[,2])
        } else if (tolower(language) == "r") {
          matches <- str_match(all_lines, import_pattern_r)
          detected_libs <- unique(matches[,2])
        }
        detected_libs <- detected_libs[!is.na(detected_libs)]
      }
    }
    
    tibble(
      FileName = fname,
      Language = language,
      Kernel = display_name,
      NbFormat = format_version,
      TotalCells = num_cells,
      MarkdownCells = markdown_cells,
      CodeCells = num_code_cells,
      doc_ratio = round(markdown_cells / (num_code_cells + 0.001), 2),
      HasOutputs = has_output,
      ErrorOutputs = error_count,
      ExecOrderLinear = exec_order_linear,
      Libraries = paste(detected_libs, collapse = ", "),
      Status = "Success"
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname, Language = "ERROR", Kernel = "", NbFormat = "",
      TotalCells = NA, MarkdownCells = NA, CodeCells = NA, doc_ratio = NA,
      HasOutputs = NA, ErrorOutputs = NA, ExecOrderLinear = NA,
      Libraries = "", Status = paste("Failed:", e$message)
    )
  })
}

# 4. Run Analysis --------------------------------------------------------------
message("Parsing notebooks...")
report <- purrr::map_dfr(ipynb_files, process_notebook)

# 5. Export Results ------------------------------------------------------------
output_dir <- "Results/Inspect_ipynb"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, paste0("Jupyter_Report_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write.csv(report, output_file, row.names = FALSE)

message(paste("✅ Success! Report saved to:", output_file))