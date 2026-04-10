#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_Code_Script.R
# Description: Standalone static analysis tool for R/Quarto code.
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

# Load required packages silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(tools)
  # rstudioapi is strictly optional/interactive, so we don't force load it here
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic (Hybrid)
# ------------------------------------------------------------------------------

if (interactive()) {
  # INTERACTIVE MODE (e.g., RStudio)
  # Show a pop-up dialog to select the folder. 
  
  message("Running in interactive mode. Please select a directory.")
  
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Code Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  
  if (is.null(target_dir)) {
    stop("No directory selected. Script aborted.", call. = FALSE)
  }
  
  # Default output in interactive mode
  output_dir <- file.path(getwd(), "Results/Inspect_Code")
  
} else {
  # NON-INTERACTIVE MODE (e.g., HPC or command-line)
  # Get directory from command-line arguments.
  
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    stop("No directory path provided. Usage: Rscript Inspect_Code_Script.R /path/to/folder [output_dir]", call. = FALSE)
  } else {
    target_dir <- args[1]
    
    if (!dir.exists(target_dir)) {
      stop(paste("Directory does not exist:", target_dir), call. = FALSE)
    }
    
    # Check if a second argument (output dir) was provided
    output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results")
  }
}

# Ensure output directory exists
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

message(sprintf("Starting analysis on: %s", target_dir))
message(sprintf("Results will be saved to: %s", output_dir))


# ------------------------------------------------------------------------------
# 2. Find Files
# ------------------------------------------------------------------------------
code_files <- list.files(
  path = target_dir,
  pattern = "\\.(R|qmd|Rmd)$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(sprintf("Found %d code files.", length(code_files)))


# ------------------------------------------------------------------------------
# 3. Define Analysis Function
# ------------------------------------------------------------------------------
analyze_r_file <- function(file_path) {
  
  fname <- basename(file_path)
  
  # Regex Patterns
  patterns <- list(
    library_call = "(?:library|require|p_load)\\s*\\(\\s*[\"']?([a-zA-Z0-9\\.]+)[\"']?\\s*\\)",
    implicit_call = "([a-zA-Z0-9\\.]+)::[a-zA-Z0-9_\\.]+",
    tokens = "(?:ghp_|sk-|xoxb-|xoxp-)[a-zA-Z0-9]+"
  )
  
  # Risk Patterns
  risk_patterns <- list(
    "Hard Setwd"    = "setwd\\s*\\(",
    "System Call"   = "(?:system|shell|system2)\\s*\\(",
    "Web Download"  = "(?:download\\.file|curl_download)\\s*\\(",
    "Source File"   = "source\\s*\\("
  )
  
  # Absolute Path Pattern
  abs_path_pattern <- "(?:[a-zA-Z]:\\\\|/Users/|/home/|/scratch/)"
  
  tryCatch({
    # Read Safely
    raw_lines <- readr::read_lines(file_path, lazy = FALSE)
    
    # Syntax Validation
    syntax_status <- "Valid"
    tryCatch({
      parse(file = file_path, keep.source = FALSE)
    }, error = function(e) {
      # Clean up the error message (remove newlines/excess whitespace)
      clean_msg <- gsub("[\r\n]+", " ", e$message)
      syntax_status <<- paste("Error:", clean_msg)
    })
    
    # Strip Comments
    clean_lines <- gsub("#.*", "", raw_lines)
    content_str <- paste(clean_lines, collapse = "\n")
    
    # Extract Dependencies
    lib_matches <- str_match_all(content_str, patterns$library_call)[[1]]
    explicit_pkgs <- if (length(lib_matches) > 0) lib_matches[, 2] else character(0)
    
    colon_matches <- str_match_all(content_str, patterns$implicit_call)[[1]]
    implicit_pkgs <- if (length(colon_matches) > 0) colon_matches[, 2] else character(0)
    
    all_pkgs <- unique(c(explicit_pkgs, implicit_pkgs))
    all_pkgs <- setdiff(all_pkgs, "base")
    packages_str <- paste(sort(all_pkgs), collapse = ", ")
    
    # Identify Risks
    risks_found <- names(risk_patterns) %>% 
      map_chr(function(risk_name) {
        if (any(str_detect(clean_lines, risk_patterns[[risk_name]]))) return(risk_name) else return(NA)
      }) %>% 
      discard(is.na) %>% 
      paste(collapse = "; ")
    
    # Count Absolute Paths
    num_abs_paths <- sum(str_count(clean_lines, abs_path_pattern))
    
    # Scan Secrets (in RAW lines)
    num_tokens <- sum(str_count(raw_lines, patterns$tokens))
    
    tibble(
      FileName = fname,
      FileType = tools::file_ext(fname),
      Syntax_Check = syntax_status,
      Packages = substr(packages_str, 1, 150),
      AbsPathsFound = num_abs_paths,
      Other_Risks = risks_found,
      Potential_Secrets = num_tokens,
      Status = "Success"
    )
    
  }, error = function(e) {
    tibble(
      FileName = fname,
      FileType = tools::file_ext(fname),
      Syntax_Check = paste("File Read Error:", e$message),
      Packages = "",
      AbsPathsFound = NA,
      Other_Risks = "",
      Potential_Secrets = NA,
      Status = "Failed"
    )
  })
}

# ------------------------------------------------------------------------------
# 4. Execute Analysis
# ------------------------------------------------------------------------------
if (length(code_files) > 0) {
  report <- purrr::map_dfr(code_files, analyze_r_file)
  
  # 5. Save Results
  output_file <- file.path(output_dir, paste0("Code_Inspection", Sys.Date(), ".csv"))
  write_csv(report, output_file)
  
  message(sprintf("Analysis complete. Report saved to: %s", output_file))
  
} else {
  message("No code files found in the target directory.")
}