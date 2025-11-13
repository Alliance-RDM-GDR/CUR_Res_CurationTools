#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
#
# TITLE: Batch GeoPackage (.gpkg) Inspector
# AUTHOR: Natalie Williams (Adapted by Gemini)
# DATE: 2025-11-13
#
# DESCRIPTION:
# This script inspects all GeoPackage files within a given directory.
# For each .gpkg file, it lists all layers, generates a text report with
# summaries (str, head, summary) for each layer, and saves a static plot (PNG).
#
# USAGE:
#
# 1. INTERACTIVE (RStudio):
#    - Source this script. A dialog box will appear to select a DIRECTORY.
#
# 2. NON-INTERACTIVE (HPC / Command-Line):
#    - Rscript check_all_gpkgs.R /path/to/your/folder_with_gpkgs
#
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(rstudioapi))

# --- 1. GET TARGET DIRECTORY ---
# CHANGED: This now asks for a directory, not a file.
target_dir <- ""

if (interactive()) {
  # INTERACTIVE MODE
  message("Running in interactive mode. Please select a DIRECTORY containing .gpkg files.")
  target_dir <- rstudioapi::selectDirectory(
    caption = "Select Folder with GeoPackages"
  )
  if (is.null(target_dir)) {
    stop("No directory selected. Script aborted.", call. = FALSE)
  }
} else {
  # NON-INTERACTIVE MODE
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    # CHANGED: Updated usage message
    stop("No directory path provided. Usage: Rscript check_all_gpkgs.R /path/to/your/folder", call. = FALSE)
  } else {
    target_dir <- args[1]
    # CHANGED: Check if directory exists, not file
    if (!dir.exists(target_dir)) {
      stop(paste("Directory does not exist:", target_dir), call. = FALSE)
    }
  }
}

message(paste("Analyzing directory:", target_dir))

# --- 2. FIND ALL .GPKG FILES ---
# NEW STEP: Find all .gpkg files in the target directory
message("Finding .gpkg files...")
gpkg_files <- list.files(
  path = target_dir,
  pattern = "\\.gpkg$", # Regex to find files ending in .gpkg
  recursive = TRUE,     # Search sub-folders
  full.names = TRUE,    # Get the full path
  ignore.case = TRUE
)

if (length(gpkg_files) == 0) {
  stop("No .gpkg files found in the specified directory.", call. = FALSE)
}

message(paste("Found", length(gpkg_files), ".gpkg files to process."))


# --- 3. MASTER PROCESSING LOOP ---
# NEW STEP: Loop over every file found. The original script's logic
# (steps 2, 3, 4) is now placed inside this loop.

for (target_file in gpkg_files) {
  
  message(paste("\n--- Processing file:", basename(target_file), "---"))
  
  # This outer tryCatch will skip a file if it's completely unreadable
  tryCatch({
    
    # --- 3a. SETUP OUTPUT (Original Step 2) ---
    # Create a results folder based on the filename
    file_basename <- tools::file_path_sans_ext(basename(target_file))
    output_dir <- file.path(getwd(), "Results/FileOpen_gpkg", paste0("Check_", file_basename))
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Start a log file for text output
    log_file <- file.path(output_dir, paste0(file_basename, "_Report.txt"))
    sink(log_file)
    
    cat(paste("REPORT FOR:", target_file, "\n"))
    cat(paste("DATE:", Sys.time(), "\n"))
    cat("--------------------------------------------------------\n\n")
    
    # --- 3b. INSPECT LAYERS (Original Step 3) ---
    message("Reading file structure...")
    
    # Get list of layers. Note: The tryCatch here is removed, as the
    # outer loop's tryCatch will handle a failure at this stage.
    layers_info <- st_layers(target_file)
    print(layers_info)
    cat("\n--------------------------------------------------------\n")
    
    
    # --- 3c. PROCESS EACH LAYER (Original Step 4) ---
    # Loop through every layer found in this file
    for (i in seq_along(layers_info$name)) {
      
      layer_name <- layers_info$name[i]
      geom_type <- layers_info$geomtype[i] # e.g., "Point", "Polygon"
      
      message(paste("Processing layer:", layer_name))
      
      cat(paste("\nLAYER:", layer_name, "\n"))
      cat(paste("GEOMETRY TYPE:", geom_type[[1]], "\n"))
      
      # This inner tryCatch handles errors at the *layer* level
      tryCatch({
        layer_data <- st_read(target_file, layer = layer_name, quiet = TRUE)
        
        cat("\n--- CRS INFO ---\n")
        print(st_crs(layer_data))
        
        cat("\n--- STRUCTURE (str) ---\n")
        str(layer_data)
        
        cat("\n--- SUMMARY STATS ---\n")
        print(summary(layer_data))
        
        cat("\n--------------------------------------------------------\n")
        
        if (!is.null(st_geometry(layer_data))) {
          plot_file <- file.path(output_dir, paste0("Map_", layer_name, ".png"))
          
          png(filename = plot_file, width = 800, height = 600)
          plot(st_geometry(layer_data), main = paste("Layer:", layer_name), axes = TRUE)
          dev.off()
        }
        
      }, error = function(e) {
        cat(paste("\nERROR processing layer:", layer_name, "\n"))
        cat(paste("Message:", e$message, "\n"))
        message(paste("Error on layer", layer_name, ":", e$message))
      })
    }
    
    # Close the log file for THIS file
    sink()
    message(paste("Process complete. Results saved to:", output_dir))
    
  }, error = function(e) {
    # This catches errors for the *entire file* (e.g., st_layers failed)
    message(paste("--- CRITICAL ERROR ---"))
    message(paste("Failed to process file:", target_file))
    message(paste("Specific error:", e$message))
    message("Skipping this file and continuing.\n")
    
    # Ensure sink is closed on error
    if(sink.number() > 0) {
      sink() 
    }
  })
}

message("\nBatch processing complete.")