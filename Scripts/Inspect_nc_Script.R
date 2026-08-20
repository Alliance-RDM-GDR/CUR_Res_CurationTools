#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_nc_Script.R
# Purpose: Batch inspection of NetCDF (.nc) files.
#          Phase A: Inventory (Usability Scan - Spatial & Data Health)
#          Phase B: Deep Metadata (Extraction of all Attributes/Dimensions)
# Usage:   Rscript Inspect_nc_Script.R <target_directory>
# ==============================================================================

# 1. Setup & Directory Selection (Hybrid: Interactive / HPC) ------------------
suppressPackageStartupMessages({
  library(tidyverse)
  library(tidync)
  library(ncmeta)
})

if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Data Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_nc")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Usage: Rscript Inspect_nc_Script.R <input_dir> [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir))
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_nc")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting NetCDF analysis on:", target_dir))
message(sprintf("Results will be saved to: %s", output_dir))

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
    # Read a tiny sample to check for 100% NaNs
    sample_data <- tnc %>%
      activate(first_var) %>%
      hyper_tibble(select_var = first_var)

    val_col <- first_var
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
nc_files <- list.files(target_dir, pattern = "\\.nc[4]?$", full.names = TRUE, recursive = TRUE, ignore.case = TRUE)
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
timestamp <- format(Sys.Date(), "%Y%m%d")

# Save (write_excel_csv adds a UTF-8 BOM so Excel renders non-ASCII correctly)
write_excel_csv(inventory_results, file.path(output_dir, paste0("NetCDF_Inventory_", dir_label, "_", timestamp, ".csv")))

# Save Deep Metadata
write_excel_csv(nc_dimensions, file.path(output_dir, paste0("NetCDF_Dimensions_", dir_label, "_", timestamp, ".csv")))
write_excel_csv(nc_attributes_global, file.path(output_dir, paste0("NetCDF_Global_Attributes_", dir_label, "_", timestamp, ".csv")))
write_excel_csv(nc_variables_with_attributes, file.path(output_dir, paste0("NetCDF_Variables_Attributes_", dir_label, "_", timestamp, ".csv")))

message(paste("✅ Process Complete."))
message(paste("   4 Reports saved to:", output_dir))