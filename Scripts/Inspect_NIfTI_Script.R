#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_NIfTI_Script.R
# Purpose: Header-only metadata extraction and screening for NIfTI neuroimaging
#          volumes (.nii and .nii.gz; NIfTI-1 and NIfTI-2, either byte order),
#          the standard file format for MRI/fMRI data. Reads only the first
#          348 or 540 bytes of each file (the header), so it stays fast on
#          hundreds of multi-hundred-MB volumes.
#
# What it reports per file: NIfTI version and byte order, array dimensions,
#   data type and bits per voxel, voxel size and time step, spatial/temporal
#   units, whether a spatial orientation is defined (qform/sform codes), the
#   scaling slope/intercept, and a size check (does the file hold exactly the
#   number of bytes the header says it should?).
#
# Curation-relevant checks built in:
#   * Spatial orientation: qform_code and sform_code both 0 means the file
#     carries no mapping from voxel indices to real-world/scanner space. That
#     is the neuroimaging counterpart of a raster with no CRS: not necessarily
#     wrong (some derived products), but worth asking the depositor about.
#   * Truncation/corruption: for uncompressed files, the expected size is
#     vox_offset + (product of dimensions) x (bits per voxel / 8). A smaller
#     actual size means the file was cut short. (Not checkable on .gz without
#     decompressing the whole file, so it is reported as "not checked".)
#   * De-identification screen: the free-text header fields descrip (80
#     bytes), aux_file (24) and intent_name (16) are common places for
#     scanner software, a protocol name, or occasionally a name/ID to end up.
#     Following this project's rule of not writing potentially identifying
#     values into curation outputs, the report records ONLY whether each field
#     is non-empty (and descrip's length), never its content. A flagged file
#     is then inspected by hand.
#
# Field offsets: NIfTI-1 offsets were validated against 610 real NIfTI-1
# volumes (dataset 1814): for every file the header-implied size matched the
# actual file size, which is only true if dim, bitpix and vox_offset are read
# from the right bytes. NIfTI-2 offsets follow the official nifti2.h header
# (struct nifti_2_header, 540 bytes, packed, no padding); they were exercised
# on a synthetic file built to that layout but NOT on a real-world NIfTI-2
# file, and rows from such files say so in Status.
#
# Sources for the layout:
#   NIfTI-1: https://nifti.nimh.nih.gov/nifti-1/
#   NIfTI-2: https://www.nitrc.org/docman/view.php/26/1302/nifti2_doc.html
#
# Usage:   Rscript Inspect_NIfTI_Script.R <target_directory> [output_dir]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select NIfTI Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_NIfTI")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_NIfTI_Script.R /path/to/nifti_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_NIfTI")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
target_dir <- normalizePath(target_dir, winslash = "/", mustWork = TRUE)
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(target_dir))

message(paste("Starting NIfTI analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
nii_files <- list.files(
  path = target_dir,
  pattern = "\\.nii(\\.gz)?$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
nii_files <- nii_files[!grepl("Curation_Results", nii_files, ignore.case = TRUE)]

message(paste("Found", length(nii_files), "NIfTI file(s)."))

if (length(nii_files) == 0) {
  message("No NIfTI files found. Exiting.")
  quit(status = 0)
}

# 3. Lookup tables -------------------------------------------------------------
dtype_names <- c(
  "2" = "uint8", "4" = "int16", "8" = "int32", "16" = "float32", "32" = "complex64",
  "64" = "float64", "128" = "RGB24", "256" = "int8", "512" = "uint16", "768" = "uint32",
  "1024" = "int64", "1280" = "uint64", "1536" = "float128", "1792" = "complex128",
  "2048" = "complex256", "2304" = "RGBA32"
)

spatial_unit <- function(u) {
  switch(as.character(bitwAnd(as.integer(u), 7L)),
         "0" = "unknown", "1" = "meter", "2" = "mm", "3" = "micron", "other")
}
temporal_unit <- function(u) {
  switch(as.character(bitwAnd(as.integer(u), 56L)),
         "0" = "unknown", "8" = "sec", "16" = "msec", "24" = "usec",
         "32" = "Hz", "40" = "ppm", "48" = "rad/s", "other")
}

# 4. One-row result constructors -------------------------------------------------
# Success and failure rows must share identical column names AND types so
# bind_rows() never fails on a mixed batch.
make_row <- function(fname, rel, compressed = NA, version = NA_integer_, endian = NA_character_,
                     dims = NA_character_, n_dims = NA_integer_, datatype = NA_character_,
                     bitpix = NA_integer_, voxel = NA_character_, dt4 = NA_real_,
                     sp_units = NA_character_, t_units = NA_character_, vox_offset = NA_real_,
                     slope = NA_real_, inter = NA_real_, qform = NA_integer_, sform = NA_integer_,
                     has_orient = NA, magic = NA_character_, expected = NA_real_,
                     actual = NA_real_, size_check = NA_character_,
                     descrip_ne = NA, descrip_len = NA_integer_, aux_ne = NA, intent_ne = NA,
                     status = "Success") {
  tibble(
    FileName = fname, RelativePath = rel, Compressed = compressed,
    NIfTI_Version = version, Byte_Order = endian,
    Dimensions = dims, N_Dims = n_dims, Datatype = datatype, BitPix = bitpix,
    Voxel_Size = voxel, Pixdim4_TR = dt4,
    Spatial_Units = sp_units, Temporal_Units = t_units, Vox_Offset = vox_offset,
    Scl_Slope = slope, Scl_Inter = inter, Qform_Code = qform, Sform_Code = sform,
    Has_Spatial_Orientation = has_orient, Magic = magic,
    Expected_Size_Bytes = expected, Actual_Size_Bytes = actual, Size_Check = size_check,
    Descrip_Nonempty = descrip_ne, Descrip_Length = descrip_len,
    Aux_File_Nonempty = aux_ne, Intent_Name_Nonempty = intent_ne,
    Status = status
  )
}

read_head <- function(fp, is_gz) {
  con <- if (is_gz) gzfile(fp, "rb") else file(fp, "rb")
  on.exit(close(con))
  readBin(con, "raw", n = 540)
}

# 5. Per-file header parse -------------------------------------------------------
inspect_nifti <- function(fp) {
  fname <- basename(fp)
  rel <- sub(paste0(target_dir, "/"), "", fp, fixed = TRUE)
  is_gz <- grepl("\\.gz$", fp, ignore.case = TRUE)

  tryCatch({
    h <- read_head(fp, is_gz)
    if (length(h) < 348) stop("file is shorter than a NIfTI-1 header (348 bytes)")

    sz_le <- readBin(h[1:4], "integer", size = 4, endian = "little")
    sz_be <- readBin(h[1:4], "integer", size = 4, endian = "big")
    if (sz_le == 348) { ver <- 1L; end <- "little"
    } else if (sz_be == 348) { ver <- 1L; end <- "big"
    } else if (sz_le == 540) { ver <- 2L; end <- "little"
    } else if (sz_be == 540) { ver <- 2L; end <- "big"
    } else {
      stop(sprintf("sizeof_hdr is %d (little-endian read) / %d (big-endian read), neither 348 nor 540: not a NIfTI-1/2 header (could be ANALYZE 7.5 or another format)", sz_le, sz_be))
    }
    if (ver == 2L && length(h) < 540) stop("NIfTI-2 file shorter than its 540-byte header")

    # h is a 1-based raw vector; offsets below are the 0-based byte offsets from the specs.
    rd_int <- function(off, n = 1, size = 2) readBin(h[(off + 1):(off + n * size)], "integer", n = n, size = size, endian = end)
    rd_num <- function(off, n = 1, size = 4) readBin(h[(off + 1):(off + n * size)], "numeric", n = n, size = size, endian = end)
    rd_txt <- function(off, len) {
      x <- h[(off + 1):(off + len)]
      x <- x[x != as.raw(0)]
      if (length(x)) rawToChar(x) else ""
    }

    if (ver == 1L) {
      dim_v <- rd_int(40, 8, 2); datatype <- rd_int(70, 1, 2); bitpix <- rd_int(72, 1, 2)
      pixdim <- rd_num(76, 8, 4); vox_offset <- rd_num(108, 1, 4)
      slope <- rd_num(112, 1, 4); inter <- rd_num(116, 1, 4)
      xyzt <- as.integer(h[124])
      descrip <- rd_txt(148, 80); aux <- rd_txt(228, 24); intent <- rd_txt(328, 16)
      qform <- rd_int(252, 1, 2); sform <- rd_int(254, 1, 2)
      magic <- rd_txt(344, 4)
    } else {
      datatype <- rd_int(12, 1, 2); bitpix <- rd_int(14, 1, 2)
      dim_v <- rd_int(16, 8, 8); pixdim <- rd_num(104, 8, 8); vox_offset <- rd_int(168, 1, 8)
      slope <- rd_num(176, 1, 8); inter <- rd_num(184, 1, 8)
      descrip <- rd_txt(240, 80); aux <- rd_txt(320, 24)
      qform <- rd_int(344, 1, 4); sform <- rd_int(348, 1, 4)
      xyzt <- rd_int(500, 1, 4); intent <- rd_txt(508, 16)
      magic <- rd_txt(4, 3)
    }

    n_dims <- dim_v[1]
    if (is.na(n_dims) || n_dims < 1 || n_dims > 7) stop(sprintf("implausible dimension count (dim[0] = %s)", n_dims))
    dims <- dim_v[2:(n_dims + 1)]

    # pixdim[1] (R index 1) is qfac; the spatial steps dx, dy, dz are R indices 2..4.
    voxel_size <- paste(round(pixdim[2:(min(n_dims, 3L) + 1L)], 4), collapse = " x ")
    dt4 <- if (n_dims >= 4) pixdim[5] else NA_real_

    dt_name <- unname(dtype_names[as.character(datatype)])
    if (is.na(dt_name)) dt_name <- paste("unknown code", datatype)

    expected <- vox_offset + prod(as.numeric(dims)) * (bitpix / 8)
    actual <- file.size(fp)
    size_check <- if (is_gz) {
      "not checked (compressed)"
    } else if (actual == expected) {
      "match"
    } else if (actual < expected) {
      "TRUNCATED (file smaller than the header implies)"
    } else {
      "larger than the header implies (extra trailing bytes)"
    }

    make_row(
      fname, rel, compressed = is_gz, version = ver, endian = end,
      dims = paste(dims, collapse = " x "), n_dims = as.integer(n_dims),
      datatype = dt_name, bitpix = as.integer(bitpix),
      voxel = voxel_size, dt4 = dt4,
      sp_units = spatial_unit(xyzt), t_units = temporal_unit(xyzt),
      vox_offset = vox_offset, slope = slope, inter = inter,
      qform = as.integer(qform), sform = as.integer(sform),
      has_orient = (qform > 0 || sform > 0), magic = magic,
      expected = expected, actual = actual, size_check = size_check,
      descrip_ne = nzchar(descrip), descrip_len = nchar(descrip),
      aux_ne = nzchar(aux), intent_ne = nzchar(intent),
      status = if (ver == 2L) "Success (NIfTI-2 parsed per the official header spec; not validated against a real NIfTI-2 file)" else "Success"
    )
  }, error = function(e) {
    make_row(fname, rel, compressed = is_gz, status = paste("Failed:", conditionMessage(e)))
  })
}

# 6. Execution -----------------------------------------------------------------
message("Reading NIfTI headers (only the first 348/540 bytes of each file)...")
report <- map_dfr(nii_files, inspect_nifti)

# 7. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("NIfTI_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = names(report),
  Type = map_chr(report, function(col) {
    if (is.logical(col)) "Logical" else if (is.integer(col)) "Integer" else if (is.numeric(col)) "Numeric" else "Text"
  }),
  Description = c(
    "File name.",
    "Path relative to the scanned directory.",
    "TRUE for .nii.gz (gzip-compressed).",
    "1 or 2, from the sizeof_hdr field (348 = NIfTI-1, 540 = NIfTI-2).",
    "little or big, the byte order the header was written in.",
    "Array dimensions (dim[1..dim[0]]), e.g. \"64 x 64 x 30 x 200\" for a 4-D fMRI run.",
    "Number of dimensions (dim[0]); 3 for a structural volume, 4 for time series.",
    "Voxel data type from the datatype code (e.g. float32, int16).",
    "Bits per voxel.",
    "Voxel size along the first (up to) three spatial axes, in Spatial_Units.",
    "pixdim[4], the step along the 4th dimension (the repetition time TR for fMRI), in Temporal_Units; blank for volumes with fewer than 4 dimensions.",
    "Spatial unit code from xyzt_units (unknown, meter, mm, micron).",
    "Temporal unit code from xyzt_units (unknown, sec, msec, usec, Hz, ppm, rad/s).",
    "Byte offset where voxel data starts (vox_offset).",
    "scl_slope: voxel values should be multiplied by this (0 or NaN means no scaling).",
    "scl_inter: added after multiplying by scl_slope.",
    "qform_code: 0 unknown, 1 scanner anatomical, 2 aligned anatomical, 3 Talairach, 4 MNI-152.",
    "sform_code: same coding as qform_code.",
    "TRUE if qform_code or sform_code is above 0, i.e. the file defines how voxel indices map to real-world space; FALSE (both 0) means no spatial orientation is defined, worth asking the depositor about.",
    "Magic string identifying the format (n+1 or ni1 for NIfTI-1, n+2 for NIfTI-2).",
    "Size the file should have if uncompressed: vox_offset + product of dimensions x bits per voxel / 8. For .nii.gz this is the size after decompression.",
    "Actual file size on disk in bytes. For .nii.gz this is the compressed size, so it is not comparable to Expected_Size_Bytes (see Size_Check).",
    "match, TRUNCATED, larger than the header implies, or not checked (compressed).",
    "TRUE if the free-text descrip field (80 bytes) is not empty. The value itself is deliberately NOT recorded; inspect flagged files by hand.",
    "Character length of descrip (0 if empty); length only, never the content.",
    "TRUE if the aux_file field (24 bytes) is not empty (value not recorded).",
    "TRUE if the intent_name field (16 bytes) is not empty (value not recorded).",
    "Success, or Failed: <reason> (e.g. not a NIfTI header)."
  )
)
codebook_file <- file.path(output_dir, "NIfTI_Report_Codebook.csv")
write_excel_csv(codebook, codebook_file)

ok <- report %>% filter(startsWith(Status, "Success"))
message(sprintf("Process complete. %d file(s) read, %d failed.", nrow(report), nrow(report) - nrow(ok)))
if (nrow(ok) > 0) {
  message(sprintf("  Distinct dimension sets: %d", n_distinct(ok$Dimensions)))
  n_txt <- sum(ok$Descrip_Nonempty | ok$Aux_File_Nonempty | ok$Intent_Name_Nonempty, na.rm = TRUE)
  if (n_txt > 0) message(sprintf("  NOTE: %d file(s) have a non-empty free-text header field (descrip/aux_file/intent_name). Inspect by hand before publication.", n_txt))
  n_orient <- sum(!ok$Has_Spatial_Orientation, na.rm = TRUE)
  if (n_orient > 0) message(sprintf("  NOTE: %d file(s) define no spatial orientation (qform_code and sform_code both 0).", n_orient))
  n_trunc <- sum(startsWith(ok$Size_Check, "TRUNCATED"), na.rm = TRUE)
  if (n_trunc > 0) message(sprintf("  WARNING: %d file(s) are smaller than their header implies (truncated or corrupt).", n_trunc))
}
message(paste("Report saved to:", output_file))
