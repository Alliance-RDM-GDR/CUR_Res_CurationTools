#!/usr/bin/env Rscript

# ==============================================================================
# Script: Restructure_Dataset_Script.R
# Purpose: Generic, reusable engine for proposing a reorganized ("v2") file
#          layout to a depositor without ever touching the original ("v1")
#          submission. Given a mapping table of old path -> new path, it
#          copies every file to its new location and verifies the copy is
#          byte-identical via checksum, producing a full audit log.
#
#          This script does NOT decide new file names or folder structure —
#          that logic is dataset-specific (it depends on that dataset's own
#          metadata, e.g. an accompanying Excel file) and must be generated
#          separately as the mapping CSV this script consumes. This script is
#          the safe, auditable, reusable "do the copy correctly" engine only.
#
# Mapping CSV requirements: two columns, "Old_RelPath" and "New_RelPath",
# both relative to <source_dir> and <output_dir> respectively (forward
# slashes). One row per file to be copied.
#
# Usage:   Rscript Restructure_Dataset_Script.R <mapping_csv> <source_dir> <output_dir> [log_dir]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(digest)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: Rscript Restructure_Dataset_Script.R <mapping_csv> <source_dir> <output_dir> [log_dir]", call. = FALSE)
}
mapping_csv <- args[1]
source_dir  <- args[2]
output_dir  <- args[3]
log_dir     <- if (length(args) >= 4) args[4] else output_dir

if (!file.exists(mapping_csv)) stop(paste("Mapping CSV not found:", mapping_csv), call. = FALSE)
if (!dir.exists(source_dir)) stop(paste("Source directory not found:", source_dir), call. = FALSE)
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

mapping <- read_csv(mapping_csv, show_col_types = FALSE)
required_cols <- c("Old_RelPath", "New_RelPath")
if (!all(required_cols %in% names(mapping))) {
  stop(paste("Mapping CSV must have columns:", paste(required_cols, collapse = ", ")), call. = FALSE)
}

message(sprintf("Restructuring %d file(s) from %s to %s", nrow(mapping), source_dir, output_dir))

# Duplicate destination check: two different source files mapped to the same
# new path would silently overwrite one another during the copy.
dupe_targets <- mapping$New_RelPath[duplicated(mapping$New_RelPath)]
if (length(dupe_targets) > 0) {
  stop(sprintf("Mapping CSV has %d duplicate New_RelPath value(s) (e.g. %s). Fix the mapping before running the copy.",
               length(dupe_targets), dupe_targets[1]), call. = FALSE)
}

copy_and_verify <- function(old_rel, new_rel) {
  src <- file.path(source_dir, old_rel)
  dst <- file.path(output_dir, new_rel)

  if (!file.exists(src)) {
    return(tibble(Old_RelPath = old_rel, New_RelPath = new_rel, Size_Bytes = NA_real_,
                   Checksum_Match = NA, Status = "Source file not found"))
  }

  dir.create(dirname(dst), recursive = TRUE, showWarnings = FALSE)

  tryCatch({
    ok <- file.copy(src, dst, overwrite = TRUE, copy.date = TRUE)
    if (!ok) {
      return(tibble(Old_RelPath = old_rel, New_RelPath = new_rel, Size_Bytes = NA_real_,
                     Checksum_Match = NA, Status = "Copy failed"))
    }
    src_hash <- digest::digest(src, algo = "md5", file = TRUE)
    dst_hash <- digest::digest(dst, algo = "md5", file = TRUE)
    match <- identical(src_hash, dst_hash)

    tibble(
      Old_RelPath = old_rel,
      New_RelPath = new_rel,
      Size_Bytes = file.size(dst),
      Checksum_Match = match,
      Status = if (match) "Success" else "COPIED BUT CHECKSUM MISMATCH"
    )
  }, error = function(e) {
    tibble(Old_RelPath = old_rel, New_RelPath = new_rel, Size_Bytes = NA_real_,
           Checksum_Match = NA, Status = paste("Failed:", e$message))
  })
}

message("Copying and verifying files (this reads and hashes every file, so it will take a while for large datasets)...")
n <- nrow(mapping)
results <- vector("list", n)
for (i in seq_len(n)) {
  results[[i]] <- copy_and_verify(mapping$Old_RelPath[i], mapping$New_RelPath[i])
  if (i %% 50 == 0 || i == n) message(sprintf("  %d / %d files processed", i, n))
}
log <- bind_rows(results)

log_file <- file.path(log_dir, paste0("Restructure_Log_", format(Sys.Date(), "%Y%m%d_%H%M%S"), ".csv"))
write_excel_csv(log, log_file)

n_ok <- sum(log$Status == "Success", na.rm = TRUE)
n_bad <- sum(log$Status != "Success", na.rm = TRUE)
message(sprintf("Done. %d succeeded, %d need attention. Log saved to: %s", n_ok, n_bad, log_file))
if (n_bad > 0) {
  message("WARNING: some files did not copy cleanly. Review the log before treating v2 as complete.")
}
