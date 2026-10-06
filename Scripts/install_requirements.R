#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: install_requirements.R
# Description: Installs the R packages needed by the workshop scripts
#              (csv, nc, Extensions, Images, PDF, hdf5, sqlite, TidyData,
#              ReadmeFileList) and checks external tools.
# Usage:       Rscript Scripts/install_requirements.R
#              (or source() it from RStudio)
# ------------------------------------------------------------------------------

packages <- c(
  "tidyverse",  # all scripts
  "rstudioapi", # folder picker in RStudio (interactive mode)
  "skimr",      # csv
  "tidync",     # nc
  "ncmeta",     # nc
  "exiftoolr",  # Extensions, Images
  "digest",     # Images
  "magick",     # Images
  "pdftools",   # PDF
  "hdf5r",      # hdf5
  "DBI",        # sqlite
  "RSQLite",    # sqlite
  "readxl"      # TidyData
)

missing <- setdiff(packages, rownames(installed.packages()))
if (length(missing)) {
  message("Installing: ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("All required R packages are already installed.")
}

# Packages that still fail to load (usually missing system libraries on Linux)
failed <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

# ExifTool is an external program, downloaded by exiftoolr if absent
has_exiftool <- requireNamespace("exiftoolr", quietly = TRUE) &&
  !is.null(tryCatch(exiftoolr::exif_version(), error = function(e) NULL))
if (!has_exiftool && requireNamespace("exiftoolr", quietly = TRUE)) {
  message("ExifTool not found. Trying exiftoolr::install_exiftool() ...")
  try(exiftoolr::install_exiftool(), silent = TRUE)
  has_exiftool <- !is.null(tryCatch(exiftoolr::exif_version(), error = function(e) NULL))
}

cat("\n--- Summary ---\n")
cat("R packages:", if (length(failed)) paste("PROBLEM with", paste(failed, collapse = ", "))
    else "OK", "\n")
cat("ExifTool  :", if (has_exiftool) "OK" else
    "NOT AVAILABLE (Extensions and Images will skip metadata; on Windows it also needs Perl)", "\n")
if (length(failed)) {
  cat("\nOn Linux, magick, pdftools and hdf5r need system libraries, for example:\n",
      "  sudo apt-get install libmagick++-dev libpoppler-cpp-dev libhdf5-dev\n")
}
