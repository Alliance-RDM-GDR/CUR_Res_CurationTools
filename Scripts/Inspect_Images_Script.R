#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Images_Script.R
# Purpose: HPC-ready workflow for Image Quality Control, Fixity, and Metadata.
# Inputs:  Target Directory path (passed as command line argument).
# Outputs: SINGLE CSV Curation Report with Flags and Checksums.
# ==============================================================================

# Load required libraries silently
suppressPackageStartupMessages({
  library(tidyverse)
  library(magick)
  library(exiftoolr)
  library(digest)
})

# 1. Setup and Arguments (Hybrid: Interactive / HPC) ---------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Images Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_Images")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided. Usage: Rscript Inspect_Images_Script.R /path/to/images [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_Images")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Label for output filenames: name of the folder that was explored
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting analysis on:", target_dir))

# ==============================================================================
# 2. Inventory & Fixity (Checksums) --------------------------------------------
# ==============================================================================
message("Step 1/4: Generating inventory and calculating checksums...")

image_files <- list.files(
  path = target_dir,
  pattern = "\\.(jpg|jpeg|png|tiff|tif)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(image_files) == 0) {
  stop("No image files found in the target directory.", call. = FALSE)
}

file_inventory <- tibble(file_path = image_files) %>%
  mutate(
    filename = basename(file_path),
    # Calculate MD5 hash for fixity
    md5_checksum = map_chr(file_path, digest::digest, file = TRUE, algo = "md5")
  )

# ==============================================================================
# 3. Technical Validation (Magick) ---------------------------------------------
# ==============================================================================
message("Step 2/4: Validating file headers with Magick...")

magick_results <- purrr::map_dfr(image_files, function(fp) {
  tryCatch({
    img <- image_read(fp)
    info <- image_info(img)
    
    # We rename 'format' to 'format_magick' to avoid confusion with ExifTool data
    tibble(
      file_path = fp,
      format_magick = info$format,
      width = info$width,
      height = info$height,
      colorspace = info$colorspace,
      filesize_mb = round(info$filesize / 1024^2, 2),
      valid_image = TRUE
    )
  }, error = function(e) {
    tibble(
      file_path = fp,
      valid_image = FALSE,
      error_msg = e$message
    )
  })
})

# ==============================================================================
# 4. Deep Metadata (ExifTool) --------------------------------------------------
# ==============================================================================
message("Step 3/4: Extracting Exif metadata...")

exif_results <- tryCatch({
  exif_read(image_files) %>%
    mutate(SourceFile = image_files) 
}, error = function(e) {
  message("Warning: ExifTool extraction failed. Ensure ExifTool is installed.")
  return(data.frame(SourceFile = image_files))
})

# Select only high-value columns if they exist to keep output clean
possible_cols <- c("SourceFile", "Make", "Model", "Software", "DateTimeOriginal", "GPSLatitude", "GPSLongitude", "Megapixels")
common_cols <- intersect(names(exif_results), possible_cols)

if(length(common_cols) > 0) {
  exif_subset <- exif_results %>% select(all_of(common_cols))
} else {
  exif_subset <- exif_results
}

# ==============================================================================
# 5. Curation Intelligence (Flagging) ------------------------------------------
# ==============================================================================
message("Step 4/4: Applying Curation Flags...")

# Merge Data
full_report <- file_inventory %>%
  left_join(magick_results, by = "file_path") %>%
  left_join(exif_subset, by = c("file_path" = "SourceFile"))

# DEFENSIVE PROGRAMMING: Ensure critical columns exist (prevents crash on empty metadata)
cols_to_ensure <- c("GPSLatitude", "width", "height")
for (col in cols_to_ensure) {
  if (!col %in% names(full_report)) {
    full_report[[col]] <- NA
  }
}

# Helper function for Mode (Handles NAs safely)
get_mode <- function(v) {
  v <- na.omit(v)
  if (length(v) == 0) return(NA)
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}

mode_width <- get_mode(full_report$width)
mode_height <- get_mode(full_report$height)

# Flagging Logic
curated_data <- full_report %>%
  group_by(md5_checksum) %>%
  mutate(is_duplicate = n() > 1) %>%
  ungroup() %>%
  mutate(
    flag_duplicate = ifelse(is_duplicate, "DUPLICATE", NA),
    flag_corrupt = ifelse(exists("valid_image") & !valid_image, "CORRUPT", NA),
    flag_privacy_gps = ifelse(!is.na(GPSLatitude), "HAS_GPS_DATA", NA),
    flag_outlier = ifelse(
      !is.na(width) & !is.na(height) & (width != mode_width | height != mode_height), 
      "DIMENSION_OUTLIER", 
      NA
    )
  ) %>%
  unite("curation_flags", starts_with("flag_"), sep = "; ", na.rm = TRUE, remove = FALSE)

# ==============================================================================
# 6. Save Results --------------------------------------------------------------
# ==============================================================================
timestamp <- format(Sys.Date(), "%Y%m%d")
output_file <- file.path(output_dir, paste0("Curation_Report_Images_", dir_label, "_", timestamp, ".csv"))

write_excel_csv(curated_data, output_file)

message(paste("Success! Curation report saved to:", output_file))