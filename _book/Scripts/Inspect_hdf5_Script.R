#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_hdf5_Script.R
# Description: Deep inspection of HDF5 files (Hierarchy, Compression, Links).
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(hdf5r)      # Interface to HDF5 library
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (interactive()) {
  # INTERACTIVE MODE
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select HDF5 Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  output_dir <- file.path(getwd(), "Results")
} else {
  # HPC MODE
  if (length(args) == 0) {
    stop("Usage: Rscript Inspect_hdf5_Script.R <input_dir> [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results")
}

if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir))
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

message(sprintf("Inspecting HDF5 files in: %s", target_dir))

# ------------------------------------------------------------------------------
# 2. File Inventory
# ------------------------------------------------------------------------------
hdf5_files <- list.files(
  path = target_dir,
  pattern = "\\.(h5|hdf5|nc4)$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(sprintf("Found %d HDF5 container files.", length(hdf5_files)))

# ------------------------------------------------------------------------------
# 3. Deep Inspection Function
# ------------------------------------------------------------------------------
analyze_hdf5_structure <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    # Robust Fix: Use explicit namespace hdf5r::H5File
    h5f <- hdf5r::H5File$new(file_path, mode = "r")
    on.exit(h5f$close_all()) 
    
    contents <- h5f$ls(recursive = TRUE)
    
    purrr::map_dfr(seq_len(nrow(contents)), function(i) {
      obj_path <- contents$name[i]
      obj_type <- contents$obj_type[i]
      link_type <- contents$link.type[i]
      
      dims <- NA_character_
      dtype <- NA_character_
      compression <- "None"
      attrs_str <- ""
      
      # Risk Check: External Links
      if (link_type == "H5L_TYPE_EXTERNAL") {
        return(tibble(
          FileName = fname, Path = obj_path, Type = "EXTERNAL_LINK",
          Dimensions = NA, DataType = NA, Compression = NA, 
          Attributes = "Warning: Points to external file", Status = "Risk: External Dependency"
        ))
      }
      
      if (obj_type == "H5I_DATASET") {
        tryCatch({
          dset <- h5f[[obj_path]]
          dims <- paste(dset$dims, collapse = " x ")
          dtype <- dset$get_type()$to_text()
          
          # Compression Filters
          dcpl <- dset$create_plist
          n_filters <- dcpl$get_nfilters()
          if (n_filters > 0) {
            filters <- map_chr(0:(n_filters - 1), ~ dcpl$get_filter(.x)$name)
            compression <- paste(filters, collapse = ", ")
          }
          
          attr_list <- names(h5attributes(dset))
          if (length(attr_list) > 0) attrs_str <- paste(head(attr_list, 5), collapse = "; ")
          
        }, error = function(e) {
          dims <<- "Error reading dataset"
        })
      } else if (obj_type == "H5I_GROUP") {
        tryCatch({
          grp <- h5f[[obj_path]]
          attr_list <- names(h5attributes(grp))
          if (length(attr_list) > 0) attrs_str <- paste(head(attr_list, 5), collapse = "; ")
        }, error = function(e) {})
      }
      
      tibble(
        FileName = fname,
        Path = obj_path,
        Type = obj_type,
        Dimensions = dims,
        DataType = dtype,
        Compression = compression,
        Attributes = substr(attrs_str, 1, 100),
        Status = "Success"
      )
    })
    
  }, error = function(e) {
    tibble(
      FileName = fname, Path = "ROOT", Type = "ERROR", 
      Dimensions = NA, DataType = NA, Compression = NA, Attributes = NA,
      Status = paste("File Read Failed:", e$message)
    )
  })
}

# ------------------------------------------------------------------------------
# 4. Execute and Save
# ------------------------------------------------------------------------------
if (length(hdf5_files) > 0) {
  
  message("Analyzing structure (Deep Scan)...")
  report <- purrr::map_dfr(hdf5_files, analyze_hdf5_structure)
  
  output_file <- file.path(output_dir, paste0("HDF5_Structure_HPC_", Sys.Date(), ".csv"))
  write_csv(report, output_file)
  
  message(sprintf("Analysis complete. Report saved to: %s", output_file))
  
} else {
  message("No HDF5 files found.")
}