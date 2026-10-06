#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_FITS_Script.R
# Purpose: Header-only metadata extraction for FITS files (.fits, .fit, .fts,
#          and their .gz-compressed forms), the standard file format across
#          almost all of astronomy (images, spectra, and tabular data alike).
#          Reports every HDU (Header/Data Unit) in each file: type, dimensions,
#          bit depth, and the common descriptive/WCS keywords, without
#          reading the pixel/table data itself, so it stays fast even on
#          large multi-extension files (MEF) or large images.
#
# Why header-only, and how multi-HDU files are handled: FITSio::readFITS()
# reads the full data array into memory, which is impractical to do for
# every HDU of every file on a real astronomical archive. This script instead
# reads only the 80-character header cards via FITSio::readFITSheader() on a
# raw file connection, computes the data segment's size from BITPIX/NAXISn/
# PCOUNT/GCOUNT per the FITS Standard (data is padded to a whole number of
# 2880-byte blocks), and seeks past it to reach the next HDU's header,
# repeating until the file ends. This logic was validated against a
# purpose-built 2-HDU test file (primary image + one IMAGE extension) before
# being trusted on real data.
#
# Usage:   Rscript Inspect_FITS_Script.R <target_directory> [output_dir]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  if (!requireNamespace("FITSio", quietly = TRUE)) {
    stop("Package 'FITSio' is required but not installed. Install with install.packages('FITSio').")
  }
  library(FITSio)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select FITS Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_FITS")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_FITS_Script.R /path/to/fits_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_FITS")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting FITS analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
fits_files <- list.files(
  path = target_dir,
  pattern = "\\.(fits|fit|fts)(\\.gz)?$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
fits_files <- fits_files[!grepl("Curation_Results", fits_files, ignore.case = TRUE)]

message(paste("Found", length(fits_files), "FITS file(s)."))

if (length(fits_files) == 0) {
  message("No FITS files found. Exiting.")
  quit(status = 0)
}

# 3. Header parsing helpers -------------------------------------------------------
# FITSio::readFITSheader() returns raw 80-char cards; parse the ones we need
# ourselves rather than relying on FITSio's higher-level (data-loading) reader.
parse_header_cards <- function(hdr_lines) {
  kv <- list()
  for (line in hdr_lines) {
    key <- trimws(substr(line, 1, 8))
    if (key %in% c("COMMENT", "HISTORY", "") ) next
    if (!grepl("=", substr(line, 9, 10), fixed = TRUE)) next
    val_part <- substr(line, 11, 80)
    val_part <- sub("/.*$", "", val_part)  # strip inline comment
    val_part <- trimws(val_part)
    val_part <- gsub("^'|'$", "", val_part)  # strip FITS string quotes
    kv[[key]] <- trimws(val_part)
  }
  kv
}

get_num <- function(kv, key, default = NA_real_) {
  v <- kv[[key]]
  if (is.null(v)) return(default)
  n <- suppressWarnings(as.numeric(v))
  if (length(n) == 0 || is.na(n)) default else n
}

get_chr <- function(kv, key, default = NA_character_) {
  v <- kv[[key]]
  if (is.null(v) || v == "") default else v
}

# 4. Per-file HDU walk -----------------------------------------------------------
inspect_fits_file <- function(fp) {
  fname <- basename(fp)
  is_gz <- grepl("\\.gz$", fp, ignore.case = TRUE)

  rows <- list()
  zz <- tryCatch(if (is_gz) gzfile(fp, "rb") else file(fp, "rb"), error = function(e) NULL)
  if (is.null(zz)) {
    return(tibble(FileName = fname, HDU_Index = NA_integer_, HDU_Type = NA_character_,
                   Extension_Name = NA_character_, Dimensions = NA_character_, BitDepth = NA_character_,
                   Object = NA_character_, Telescope = NA_character_, Instrument = NA_character_,
                   Date_Obs = NA_character_, BUnit = NA_character_, Has_WCS = NA,
                   CType1 = NA_character_, CType2 = NA_character_,
                   Status = "Failed: could not open file"))
  }
  on.exit(try(close(zz), silent = TRUE), add = TRUE)

  hdu_idx <- 0
  repeat {
    hdu_idx <- hdu_idx + 1
    hdr <- tryCatch(readFITSheader(zz), error = function(e) NULL)
    if (is.null(hdr) || length(hdr) == 0) break

    kv <- parse_header_cards(hdr)

    naxis <- get_num(kv, "NAXIS", 0)
    naxis_vals <- if (!is.na(naxis) && naxis > 0) {
      vapply(seq_len(naxis), function(i) get_num(kv, paste0("NAXIS", i), NA_real_), numeric(1))
    } else numeric(0)
    dims_str <- if (length(naxis_vals) > 0) paste(naxis_vals, collapse = " x ") else "(no data array)"

    bitpix <- get_num(kv, "BITPIX", NA_real_)
    pcount <- get_num(kv, "PCOUNT", 0)
    gcount <- get_num(kv, "GCOUNT", 1)
    n_data_elements <- if (length(naxis_vals) > 0) prod(naxis_vals) else 0
    data_bytes <- (n_data_elements + pcount) * abs(bitpix) / 8 * gcount
    data_bytes <- if (is.na(data_bytes)) 0 else data_bytes
    data_blocks <- ceiling(data_bytes / 2880)

    hdu_type <- if (hdu_idx == 1) "PRIMARY" else get_chr(kv, "XTENSION", "UNKNOWN")
    has_wcs <- !is.null(kv[["CTYPE1"]])

    rows[[hdu_idx]] <- tibble(
      FileName = fname,
      HDU_Index = hdu_idx,
      HDU_Type = hdu_type,
      Extension_Name = get_chr(kv, "EXTNAME"),
      Dimensions = dims_str,
      BitDepth = as.character(bitpix),
      Object = get_chr(kv, "OBJECT"),
      Telescope = get_chr(kv, "TELESCOP"),
      Instrument = get_chr(kv, "INSTRUME"),
      Date_Obs = get_chr(kv, "DATE-OBS"),
      BUnit = get_chr(kv, "BUNIT"),
      Has_WCS = has_wcs,
      CType1 = get_chr(kv, "CTYPE1"),
      CType2 = get_chr(kv, "CTYPE2"),
      Status = "Success"
    )

    if (data_blocks > 0) {
      seek_ok <- tryCatch({ seek(zz, where = data_blocks * 2880, origin = "current"); TRUE },
                           error = function(e) FALSE)
      if (!seek_ok) break
    }
  }

  if (length(rows) == 0) {
    return(tibble(FileName = fname, HDU_Index = NA_integer_, HDU_Type = NA_character_,
                   Extension_Name = NA_character_, Dimensions = NA_character_, BitDepth = NA_character_,
                   Object = NA_character_, Telescope = NA_character_, Instrument = NA_character_,
                   Date_Obs = NA_character_, BUnit = NA_character_, Has_WCS = NA,
                   CType1 = NA_character_, CType2 = NA_character_,
                   Status = "Failed: no readable HDU (not a valid FITS file?)"))
  }
  bind_rows(rows)
}

# 5. Execution -----------------------------------------------------------------
message("Reading FITS headers (fast, no pixel/table data is loaded)...")
report <- map_dfr(fits_files, inspect_fits_file)

# 6. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("FITS_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "HDU_Index", "HDU_Type", "Extension_Name", "Dimensions", "BitDepth",
               "Object", "Telescope", "Instrument", "Date_Obs", "BUnit", "Has_WCS",
               "CType1", "CType2", "Status"),
  Type = c("Text", "Integer", "Text", "Text", "Text", "Text", "Text", "Text", "Text",
           "Text", "Text", "Logical", "Text", "Text", "Text"),
  Description = c(
    "Name of the FITS file.",
    "1-based index of this HDU within the file (1 = primary HDU).",
    'HDU type: "PRIMARY" for HDU 1, otherwise the XTENSION keyword value (e.g. "IMAGE", "TABLE", "BINTABLE").',
    "EXTNAME keyword, if present.",
    'Data array dimensions from NAXISn, e.g. "1024 x 1024"; "(no data array)" for a header-only HDU (NAXIS = 0, common for a primary HDU that only holds metadata before image extensions).',
    "BITPIX keyword (bits per data value; negative = floating point, e.g. -32 is float32, -64 is float64).",
    "OBJECT keyword (target name), if present.",
    "TELESCOP keyword, if present.",
    "INSTRUME keyword, if present.",
    "DATE-OBS keyword (observation date/time), if present.",
    "BUNIT keyword (physical units of the data values), if present.",
    "TRUE if a World Coordinate System is defined (CTYPE1 present) for this HDU, letting pixel coordinates be mapped to sky/physical coordinates; FALSE/absent WCS on an image HDU is worth asking the depositor about.",
    "CTYPE1 keyword (first WCS axis type, e.g. \"RA---TAN\"), if present.",
    "CTYPE2 keyword (second WCS axis type, e.g. \"DEC--TAN\"), if present.",
    'Either "Success", or "Failed: <reason>" if the file could not be opened or no valid HDU was found.'
  )
)
codebook_file <- file.path(output_dir, "FITS_Report_Codebook.csv")
write_excel_csv(codebook, codebook_file)

n_files <- length(unique(report$FileName))
n_no_wcs <- sum(!report$Has_WCS & report$HDU_Type %in% c("PRIMARY", "IMAGE") & report$Dimensions != "(no data array)", na.rm = TRUE)
message(sprintf("Process complete. %d file(s), %d HDU(s) total.", n_files, nrow(report)))
if (n_no_wcs > 0) message(sprintf("Note: %d image HDU(s) have no WCS (CTYPE1) defined. Worth confirming with the depositor whether that is expected.", n_no_wcs))
message(paste("Report saved to:", output_file))
