#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Raster_Script.R
# Purpose: Batch inspection of georeferenced raster files (.tif, .tiff) for
#          FAIR/archival readiness: CRS presence, extent, resolution,
#          band count, data type, and NoData value.
#          Complements Inspect_Tiff_Script.R, which covers file-level image
#          attributes (bit depth, compression) but not georeferencing.
# Usage:   Rscript Inspect_Raster_Script.R <target_directory>
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  if (!require("terra", quietly = TRUE)) {
    stop("Package 'terra' is required but not installed.")
  }
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Raster Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_Raster")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_Raster_Script.R /path/to/raster_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_Raster")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting raster analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
raster_files <- list.files(
  path = target_dir,
  pattern = "\\.tiff?$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

raster_files <- raster_files[!grepl("Curation_Results", raster_files, ignore.case = TRUE)]

message(paste("Found", length(raster_files), "TIFF file(s) to check for georeferencing."))

if (length(raster_files) == 0) {
  message("No TIFF files found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function -------------------------------------------------------
inspect_raster <- function(fp) {
  fname <- basename(fp)
  file_size_mb <- round(file.size(fp) / 1024^2, 2)

  tryCatch({
    r <- terra::rast(fp)

    crs_wkt <- terra::crs(r, describe = TRUE)
    crs_code <- if (nrow(crs_wkt) > 0 && !is.na(crs_wkt$code[1])) {
      paste0(crs_wkt$authority[1], ":", crs_wkt$code[1])
    } else if (terra::crs(r) != "") {
      "Present (non-EPSG / unregistered)"
    } else {
      "MISSING"
    }

    ext_r <- terra::ext(r)
    nodata <- tryCatch(paste(unique(terra::NAflag(r)), collapse = ", "), error = function(e) "Unknown")

    tibble(
      FileName = fname,
      Size_MB = file_size_mb,
      CRS = crs_code,
      NCol = terra::ncol(r),
      NRow = terra::nrow(r),
      NBands = terra::nlyr(r),
      XRes = round(terra::xres(r), 6),
      YRes = round(terra::yres(r), 6),
      Extent = paste0("xmin=", round(ext_r$xmin, 2), ", xmax=", round(ext_r$xmax, 2),
                       ", ymin=", round(ext_r$ymin, 2), ", ymax=", round(ext_r$ymax, 2)),
      DataType = paste(unique(terra::datatype(r)), collapse = ", "),
      NoDataValue = nodata,
      Status = "Success"
    )

  }, error = function(e) {
    tibble(
      FileName = fname, Size_MB = file_size_mb, CRS = NA, NCol = NA, NRow = NA,
      NBands = NA, XRes = NA, YRes = NA, Extent = NA, DataType = NA, NoDataValue = NA,
      Status = paste("Read Failed:", e$message)
    )
  })
}

# 4. Execution -----------------------------------------------------------------
message("Generating Raster Georeferencing Report...")
report <- map_dfr(raster_files, inspect_raster)

# 5. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("Raster_Georef_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))

write_excel_csv(report, output_file)

message(paste("Process complete."))
message(paste("   Analyzed:", nrow(report), "files"))
if (any(report$CRS == "MISSING", na.rm = TRUE)) {
  message("   WARNING: One or more rasters have no CRS defined.")
}
message(paste("   Report saved to:", output_file))
