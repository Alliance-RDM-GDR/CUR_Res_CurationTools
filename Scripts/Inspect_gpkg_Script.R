#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_GPKG_Script.R
# Description: Batch inspection of GeoPackage layers and CRS validation.
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  # We check for sf availability before proceeding
  if (!require("sf", quietly = TRUE)) {
    stop("Package 'sf' is required but not installed.")
  }
  library(tools)
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic (Hybrid)
# ------------------------------------------------------------------------------

if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select GeoPackage Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Usage: Rscript Inspect_GPKG_Script.R <input_dir> [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir))
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(sprintf("Inspecting GeoPackages in: %s", target_dir))
message(sprintf("Results will be saved to: %s", output_dir))


# ------------------------------------------------------------------------------
# 2. File Inventory
# ------------------------------------------------------------------------------
gpkg_files <- list.files(
  path = target_dir,
  pattern = "\\.gpkg$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(sprintf("Found %d GeoPackage files.", length(gpkg_files)))


# ------------------------------------------------------------------------------
# 3. Layer Analysis Function
# ------------------------------------------------------------------------------
analyze_gpkg_layers <- function(file_path) {
  
  fname <- basename(file_path)
  # Safely calculate size
  file_size_mb <- tryCatch(round(file.size(file_path) / 1024^2, 2), error = function(e) NA_real_)
  
  tryCatch({
    # Use sf::st_layers explicit call
    layer_info <- sf::st_layers(file_path)
    
    # CASE A: File is empty (0 layers)
    if (length(layer_info$name) == 0) {
      return(tibble(
        FileName = fname,
        Size_MB = file_size_mb,
        Layer = "EMPTY",
        Type = NA_character_,
        CRS = NA_character_,
        Features = 0L,
        Status = "Empty GPKG"
      ))
    }
    
    # CASE B: Iterate over layers
    purrr::map_dfr(seq_along(layer_info$name), function(i) {
      # Robust CRS extraction
      crs_val <- layer_info$crs[[i]]
      crs_code <- if (is.list(crs_val) && !is.null(crs_val$input)) {
        as.character(crs_val$input)
      } else if (is.character(crs_val)) {
        crs_val
      } else {
        "Missing"
      }
      
      tibble(
        FileName = fname,
        Size_MB = file_size_mb,
        Layer = layer_info$name[i],
        Type = paste(layer_info$geomtype[[i]], collapse = ", "),
        CRS = crs_code,
        Features = as.integer(layer_info$features[i]),
        Status = "Success"
      )
    })
    
  }, error = function(e) {
    # CASE C: Read Failure
    tibble(
      FileName = fname,
      Size_MB = if (is.na(file_size_mb)) 0 else file_size_mb,
      Layer = NA_character_, 
      Type = NA_character_, 
      CRS = NA_character_, 
      Features = NA_integer_, 
      Status = paste("Read Failed:", e$message)
    )
  })
}

# ------------------------------------------------------------------------------
# 4. Execute and Save
# ------------------------------------------------------------------------------
if (length(gpkg_files) > 0) {
  
  message("Extracting layer metadata...")
  layer_report <- purrr::map_dfr(gpkg_files, analyze_gpkg_layers)
  
  output_file <- file.path(output_dir, paste0("GPKG_Layer_Report_HPC_", dir_label, "_", Sys.Date(), ".csv"))
  write_excel_csv(layer_report, output_file)
  
  message(sprintf("Analysis complete. Report saved to: %s", output_file))
  
} else {
  message("No .gpkg files found.")
}