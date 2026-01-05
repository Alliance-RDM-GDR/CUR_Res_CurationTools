#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_tiff_Script.R
# Purpose: Batch inspection of TIFF images (.tif, .tiff) for scientific archiving.
#          - Extracts Bit Depth (Critical for high-dynamic range data)
#          - Detects Compression (Lossy vs Lossless)
#          - Identifies Color Space and Resolution
#          - Uses "Fuzzy Matching" to find metadata in non-standard tags.
# Usage:   Rscript Inspect_tiff_Script.R <target_directory>
# ==============================================================================

# Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_tiff_Script.R /path/to/tiff_files", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(magick)
})

message(paste("Starting TIFF analysis on:", target_dir))

# Inventory -----------------------------------------------------------------
tiff_files <- list.files(
  path = target_dir,
  pattern = "\\.tiff?$", 
  recursive = TRUE, 
  full.names = TRUE, 
  ignore.case = TRUE
)

message(paste("Found", length(tiff_files), "TIFF files."))

if (length(tiff_files) == 0) {
  message("No TIFF files found. Exiting.")
  quit(status = 0)
}

# Processing Function (Fuzzy Match Strategy) --------------------------------
inspect_tiff_fuzzy <- function(fp) {
  fname <- basename(fp)
  
  tryCatch({
    # A. Read Image Header
    img <- image_read(fp)
    info <- image_info(img)
    attrs <- image_attributes(img)
    
    # B. Fuzzy Extraction: Bit Depth
    # Find ANY attribute containing "depth" or "bits" (case insensitive)
    depth_check <- attrs %>% 
      filter(grepl("depth|bits", property, ignore.case = TRUE)) %>% 
      pull(value)
    
    # Logic: Use found attribute, or fallback to info$depth, or "Unknown"
    final_depth <- if(length(depth_check) > 0) {
      paste(unique(depth_check), collapse = "/") 
    } else if ("depth" %in% names(info)) {
      as.character(info$depth[1])
    } else {
      "Unknown"
    }
    
    # C. Fuzzy Extraction: Compression
    # Find ANY attribute containing "compression"
    comp_check <- attrs %>% 
      filter(grepl("compression", property, ignore.case = TRUE)) %>% 
      pull(value)
    
    final_comp <- if(length(comp_check) > 0) comp_check[1] else "Unknown"
    
    # D. Fuzzy Extraction: Resolution
    res_check <- attrs %>% 
      filter(grepl("resolution|density", property, ignore.case = TRUE)) %>% 
      pull(value)
    
    final_res <- if(length(res_check) > 0) paste(res_check[1], "DPI") else paste(info$density[1], "DPI")
    
    # E. Build Row
    tibble(
      FileName = fname,
      Dimensions = paste(info$width[1], "x", info$height[1]),
      BitDepth = final_depth,
      Compression = final_comp,
      ColorSpace = info$colorspace[1],
      Resolution = final_res,
      FileSize_MB = round(file.size(fp) / 1024^2, 2),
      Status = "Success"
    )
    
  }, error = function(e) {
    # Error Handling
    tibble(
      FileName = fname, Dimensions = NA, BitDepth = NA, Compression = NA, 
      ColorSpace = NA, Resolution = NA, FileSize_MB = NA,
      Status = paste("Error:", e$message)
    )
  })
}

# Execution -----------------------------------------------------------------
message("Generating Deep Inspection Report...")
# Use map_dfr to iterate and bind results
report <- map_dfr(tiff_files, inspect_tiff_fuzzy)

# Export --------------------------------------------------------------------
output_dir <- "Results/Inspect_tiff"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

output_file <- file.path(output_dir, paste0("TIFF_DeepScan_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write.csv(report, output_file, row.names = FALSE)

message(paste("✅ Process Complete."))
message(paste("   Analyzed:", length(unique(report$FileName)), "files"))
message(paste("   Report saved to:", output_file))