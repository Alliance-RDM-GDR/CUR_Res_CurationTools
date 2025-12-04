#!/usr/bin/env Rscript

# ---------------------------------------------------------------------------
# TITLE: NetCDF File Metadata and Quality Control
# DESCRIPTION: Scans a directory for .nc files, extracts metadata, saves CSVs.
# USAGE:
#   Interactive: Source in RStudio -> Select Directory
#   CLI/HPC:     Rscript FileOpen_nc_Script /path/to/data_folder
# ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(tidync))
suppressPackageStartupMessages(library(rstudioapi)) # For interactive selection

# --- 1. GET TARGET DIRECTORY ---
target_dir <- ""
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  target_dir <- rstudioapi::selectDirectory(caption = "Select NetCDF Directory")
  if (is.null(target_dir)) stop("No directory selected.", call. = FALSE)
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) stop("No path provided. Usage: Rscript FileOpen_nc_Script <path_to_folder>", call. = FALSE)
  target_dir <- args[1]
}

if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir), call. = FALSE)
message(paste("Analyzing:", target_dir))

# --- 2. FIND FILES ---
nc_files <- list.files(target_dir, pattern = "\\.nc$", 
                       recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
if (length(nc_files) == 0) stop("No .nc files found.", call. = FALSE)
message(paste("Found", length(nc_files), ".nc files."))

# --- 3. EXTRACT METADATA ---
message("Extracting metadata...")
safe_tidync <- purrr::safely(tidync)
processed_files <- purrr::map(nc_files, ~safe_tidync(.x)) %>% set_names(nc_files)
successful_results <- purrr::map(processed_files, "result") %>% purrr::compact()
errors <- purrr::map(processed_files, "error") %>% purrr::compact()

if (length(errors) > 0) {
  message("The following files failed to process and were skipped:")
  walk(names(errors), message)
}
if (length(successful_results) == 0) {
  stop("No NetCDF files could be successfully processed.", call. = FALSE)
}

nc_dimensions <- purrr::map(successful_results, ~.x$dimension) %>% bind_rows(.id = "FileName")
nc_variables <- purrr::map(successful_results, ~.x$variable) %>% bind_rows(.id = "FileName")
nc_attributes <- purrr::map(successful_results, ~.x$attribute) %>% bind_rows(.id = "FileName")

# --- 4. RESHAPE METADATA ---
message("Reshaping metadata...")
nc_attributes_global <- nc_attributes %>%
  filter(variable == "NC_GLOBAL") %>%
  pivot_wider(id_cols = FileName, names_from = name, values_from = value,
              values_fn = ~paste(., collapse = "; "))

nc_variables_with_attributes <- nc_variables %>%
  left_join(filter(nc_attributes, variable != "NC_GLOBAL"),
            by = c("name" = "variable", "FileName")) %>%
  pivot_wider(names_from = name.y, values_from = value,
              values_fn = ~paste(., collapse = "; "))

# --- 5. SAVE RESULTS ---
message("Saving reports...")
# Create output directory relative to the *current working directory*
out_dir <- file.path(getwd(), "Results", "FileOpen_nc")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(nc_dimensions, file.path(out_dir, paste0("NetCDF_Dimensions_", Sys.Date(), ".csv")), row.names = FALSE)
write.csv(nc_attributes_global, file.path(out_dir, paste0("NetCDF_Global_Attributes_", Sys.Date(), ".csv")), row.names = FALSE)
write.csv(nc_variables_with_attributes, file.path(out_dir, paste0("NetCDF_Variables_with_Attributes_", Sys.Date(), ".csv")), row.names = FALSE)

message(paste("Done. Results in:", out_dir))