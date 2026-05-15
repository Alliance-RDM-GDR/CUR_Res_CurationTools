#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_nc_Script.R
# Purpose: Batch inspection of NetCDF (.nc) files.
#          Phase A: Inventory (Usability Scan - Spatial & Data Health)
#          Phase B: Deep Metadata (Extraction of all Attributes/Dimensions)
# Usage:   Rscript Inspect_nc_Script.R <target_directory>
# ==============================================================================

# 1. Setup & Arguments ---------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No target directory provided.\nUsage: Rscript Inspect_nc_Script.R /path/to/netcdf_files", call. = FALSE)
}

target_dir <- args[1]

if (!dir.exists(target_dir)) {
  stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
}

# Load libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(tidync)
  library(ncmeta)
})

message(paste("Starting NetCDF analysis on:", target_dir))

# 2. Phase A: Inventory Function (Usability Scan) ------------------------------
inspect_nc_inventory <- function(fp) {
  fname <- basename(fp)
  
  # A. Safe Load
  tnc <- tryCatch(tidync(fp), error = function(e) NULL)
  
  if (is.null(tnc)) {
    return(tibble(
      FileName = fname,
      Status = "Corrupt/Unreadable",
      DimsSummary = NA,
      VarCount = NA,
      HasCRS = NA,
      DataHealth = NA
    ))
  }
  
  # B. Metadata Summary
  dims <- tnc %>% hyper_dims()
  dims_str <- paste(dims$name, collapse = " x ")
  
  vars <- tnc %>% hyper_vars()
  var_count <- length(vars$name)
  
  # C. Spatial Check (CRS)
  # Check for standard lat/lon dimensions or grid_mapping attribute
  has_lat <- any(str_detect(dims$name, "(?i)lat|y"))
  has_lon <- any(str_detect(dims$name, "(?i)lon|x"))
  
  all_atts <- ncmeta::nc_atts(fp)
  has_grid_mapping <- any(all_atts$name == "grid_mapping")
  
  spatial_status <- if (has_grid_mapping || (has_lat && has_lon)) "Georeferenced" else "No Spatial Grid"
  
  # D. Data Health Check (Sparsity)
  is_empty_label <- "Unknown"
  try({
    first_var <- vars$name[1]
    # Read a tiny sample (first 100 values) to check for 100% NaNs
    sample_data <- tnc %>% 
      activate(first_var) %>% 
      hyper_slice(select_var = first_var) %>% 
      as_tibble()
    
    val_col <- names(sample_data)[ncol(sample_data)]
    if (all(is.na(sample_data[[val_col]]))) {
      is_empty_label <- "⚠️ All NaNs (Empty)"
    } else {
      is_empty_label <- "Contains Data"
    }
  }, silent = TRUE)
  
  return(tibble(
    FileName = fname,
    Status = "Valid",
    DimsSummary = dims_str,
    VarCount = var_count,
    HasCRS = spatial_status,
    DataHealth = is_empty_label
  ))
}

# 3. Execution Phase -----------------------------------------------------------
nc_files <- list.files(target_dir, pattern = "\\.nc$", full.names = TRUE, recursive = TRUE)
message(paste("Found", length(nc_files), "NetCDF files."))

if (length(nc_files) == 0) {
  message("No files to process. Exiting.")
  quit(status = 0)
}

# --- Phase A: Run Inventory ---
message("Step 1: Running Usability Inventory...")
inventory_results <- map_dfr(nc_files, inspect_nc_inventory)

# --- Phase B: Run Deep Metadata Extraction ---
message("Step 2: Extracting Deep Metadata Attributes...")

# Safe version of tidync for deep extraction
safe_tidync <- purrr::safely(tidync)

processed_files <- purrr::map(nc_files, ~safe_tidync(.x)) %>% set_names(nc_files)
successful_results <- purrr::map(processed_files, "result") %>% purrr::compact()

# 1. Dimensions Table
nc_dimensions <- purrr::map(successful_results, ~.x$dimension) %>% 
  bind_rows(.id = "FileName") %>%
  mutate(FileName = basename(FileName))

# 2. Global Attributes (Pivoted)
nc_attributes <- purrr::map(successful_results, ~.x$attribute) %>% 
  bind_rows(.id = "FileName") %>%
  mutate(FileName = basename(FileName))

nc_attributes_global <- nc_attributes %>%
  filter(variable == "NC_GLOBAL") %>%
  pivot_wider(
    id_cols = FileName,
    names_from = name,
    values_from = value,
    values_fn = ~paste(., collapse = "; ")
  )

# 3. Variable Attributes (Joined)
nc_variables <- purrr::map(successful_results, ~.x$variable) %>% 
  bind_rows(.id = "FileName") %>%
  mutate(FileName = basename(FileName))

nc_variables_with_attributes <- nc_variables %>%
  left_join(filter(nc_attributes, variable != "NC_GLOBAL"), by = c("name" = "variable", "FileName")) %>%
  pivot_wider(
    names_from = name.y, 
    values_from = value,
    values_fn = ~paste(., collapse = "; ")
  )

# 4. Export Phase --------------------------------------------------------------
output_dir <- "Results/Inspect_nc"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

timestamp <- format(Sys.Date(), "%Y%m%d")

# Save Inventory
write.csv(inventory_results, file.path(output_dir, paste0("NetCDF_Inventory_", timestamp, ".csv")), row.names = FALSE)

# Save Deep Metadata
write.csv(nc_dimensions, file.path(output_dir, paste0("NetCDF_Dimensions_", timestamp, ".csv")), row.names = FALSE)
write.csv(nc_attributes_global, file.path(output_dir, paste0("NetCDF_Global_Attributes_", timestamp, ".csv")), row.names = FALSE)
write.csv(nc_variables_with_attributes, file.path(output_dir, paste0("NetCDF_Variables_Attributes_", timestamp, ".csv")), row.names = FALSE)

message(paste("✅ Process Complete."))
message(paste("   4 Reports saved to:", output_dir))