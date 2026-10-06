#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_LAS_Script.R
# Purpose: Batch inspection of LiDAR point cloud files (.las, .laz) for
#          archival/FAIR readiness: point count, LAS version/point format,
#          bounding box, and embedded CRS (read from the GeoTIFF-style VLR
#          tags LAS stores its projection in, when present).
# Requires: the 'rlas' R package (header-only reads; does not decompress the
#           full point cloud, so this is fast even on large files).
# Usage:   Rscript Inspect_LAS_Script.R <target_directory>
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  if (!require("rlas", quietly = TRUE)) {
    stop("Package 'rlas' is required but not installed.")
  }
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select LAS/LAZ Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_LAS")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_LAS_Script.R /path/to/las_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_LAS")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting LAS/LAZ analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
las_files <- list.files(
  path = target_dir,
  pattern = "\\.la[sz]$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
las_files <- las_files[!grepl("Curation_Results", las_files, ignore.case = TRUE)]

message(paste("Found", length(las_files), "LAS/LAZ file(s)."))

if (length(las_files) == 0) {
  message("No LAS/LAZ files found. Exiting.")
  quit(status = 0)
}

# 3. Point Format Reference (what each format ID includes) ---------------------
point_format_desc <- function(id) {
  dplyr::case_when(
    id %in% c(0)       ~ "Core (no color, no GPS time)",
    id %in% c(1)       ~ "Core + GPS time",
    id %in% c(2)       ~ "Core + RGB color",
    id %in% c(3)       ~ "Core + GPS time + RGB color",
    id %in% c(6)       ~ "Core + GPS time (LAS 1.4 extended)",
    id %in% c(7)       ~ "Core + GPS time + RGB (LAS 1.4 extended)",
    id %in% c(8)       ~ "Core + GPS time + RGB + NIR (LAS 1.4 extended)",
    TRUE               ~ paste("Format", id, "(see LAS spec)")
  )
}

# 4. Processing Function --------------------------------------------------------
inspect_las <- function(fp) {
  fname <- basename(fp)
  file_size_mb <- round(file.size(fp) / 1024^2, 2)

  tryCatch({
    h <- rlas::read.lasheader(fp)

    # CRS: LAS stores projection either as a GeoAsciiParamsTag string (older/
    # GeoTIFF-key style) or a WKT VLR (LAS 1.4 "OGC Coordinate System WKT").
    # Check both; report whichever is present, or "Not found" otherwise.
    vlrs <- h[["Variable Length Records"]]
    evlrs <- h[["Extended Variable Length Records"]]
    # Different VLR types store the projection text under different field
    # names ("tags" for GeoTIFF-key style records, "WKT OGC COORDINATE SYSTEM"
    # for LAS 1.4 WKT records) -- try each and take the first non-empty match.
    extract_crs_text <- function(vlr_entry) {
      if (is.null(vlr_entry)) return(NA_character_)
      candidate <- vlr_entry[["tags"]]
      if (is.null(candidate)) candidate <- vlr_entry[["WKT OGC COORDINATE SYSTEM"]]
      if (is.null(candidate) || length(candidate) == 0) return(NA_character_)
      paste(candidate, collapse = " ")
    }
    crs_text <- extract_crs_text(vlrs[["GeoAsciiParamsTag"]])
    if (is.na(crs_text)) crs_text <- extract_crs_text(vlrs[["WKT OGC CS"]])
    if (is.na(crs_text) && !is.null(evlrs) && length(evlrs) > 0) crs_text <- extract_crs_text(evlrs[["WKT OGC CS"]])
    if (is.na(crs_text) || trimws(crs_text) == "") {
      crs_text <- "Not found in header"
    } else {
      crs_text <- substr(crs_text, 1, 150)
    }

    tibble(
      FileName = fname,
      Size_MB = file_size_mb,
      LAS_Version = paste0(h[["Version Major"]], ".", h[["Version Minor"]]),
      Point_Format = point_format_desc(h[["Point Data Format ID"]]),
      Point_Count = h[["Number of point records"]],
      Extent = paste0("X: ", round(h[["Min X"]], 2), " to ", round(h[["Max X"]], 2),
                       " | Y: ", round(h[["Min Y"]], 2), " to ", round(h[["Max Y"]], 2),
                       " | Z: ", round(h[["Min Z"]], 2), " to ", round(h[["Max Z"]], 2)),
      CRS = crs_text,
      Generating_Software = h[["Generating Software"]],
      Creation_Year = h[["File Creation Year"]],
      Status = "Success"
    )

  }, error = function(e) {
    tibble(
      FileName = fname, Size_MB = file_size_mb, LAS_Version = NA, Point_Format = NA,
      Point_Count = NA, Extent = NA, CRS = NA, Generating_Software = NA, Creation_Year = NA,
      Status = paste("Read Failed:", e$message)
    )
  })
}

# 5. Execution -----------------------------------------------------------------
message("Reading LAS/LAZ headers (fast: header-only, does not decompress point data)...")
report <- map_dfr(las_files, inspect_las)

# 6. Export ----------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("LAS_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "Size_MB", "LAS_Version", "Point_Format", "Point_Count",
               "Extent", "CRS", "Generating_Software", "Creation_Year", "Status"),
  Type = c("Text", "Numeric", "Text", "Text", "Integer", "Text", "Text", "Text", "Integer", "Text"),
  Description = c(
    "Name of the LAS/LAZ file.",
    "File size in megabytes.",
    "LAS format version (e.g. 1.2, 1.4).",
    "What each point record stores, decoded from the LAS Point Data Format ID (e.g. core XYZ + RGB color).",
    "Total number of points in the file.",
    "Bounding box in the file's native coordinate units (X/Y/Z min-max), as stored in the header.",
    "Coordinate reference system, read from the header's GeoTIFF-style or WKT projection tag; \"Not found in header\" if neither is present.",
    "Software that generated/last wrote the file, from the header.",
    "Year the file was created, from the header.",
    'Either "Success" or "Read Failed: <error message>".'
  )
)
codebook_file <- file.path(output_dir, "LAS_Report_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(paste("Process complete. Report saved to:", output_file))
if (any(report$CRS == "Not found in header", na.rm = TRUE)) {
  message("NOTE: one or more point clouds have no embedded CRS. Confirm the coordinate system is documented in the README.")
}
