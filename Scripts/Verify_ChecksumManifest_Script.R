#!/usr/bin/env Rscript

# ==============================================================================
# Script: Verify_ChecksumManifest_Script.R
# Purpose: Verify a dataset's own checksum manifest (e.g. MANIFEST.sha256,
#          MANIFEST.md5, checksums.txt) against the files actually on disk.
#          Generic: works on any dataset that ships a manifest in the common
#          "<hex digest>  <relative path>" format (sha256sum/md5sum -c style,
#          two spaces or one, forward or back slashes).
#
# Why sampling: on a large submission (hundreds of GB, thousands of files),
# hashing every single file can take hours of pure I/O. By default this
# script verifies EVERY file below a size threshold in full, plus a random
# SAMPLE of the larger files (each hashed completely, never partially, since
# a partial hash cannot honestly confirm a match) — never claims to have
# checked more than it actually did. Missing-file and extra-file checks are
# always exhaustive (just a directory listing, not a hash), regardless of
# sampling, since that is cheap.
#
# Usage:   Rscript Verify_ChecksumManifest_Script.R <target_directory> [output_dir] [manifest_filename] [sample_n] [full_verify_below_mb]
#          manifest_filename defaults to "MANIFEST.sha256"
#          sample_n defaults to 50 (large files sampled for full-hash verification)
#          full_verify_below_mb defaults to 50 (files at/under this size, in MB, are ALWAYS fully verified)
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(digest)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Dataset Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Verify_ChecksumManifest")
  manifest_name <- "MANIFEST.sha256"
  sample_n <- 50
  full_verify_below_mb <- 50
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Verify_ChecksumManifest_Script.R /path/to/dataset [output_dir] [manifest_filename] [sample_n] [full_verify_below_mb]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Verify_ChecksumManifest")
  manifest_name <- if (length(args) >= 3) args[3] else "MANIFEST.sha256"
  sample_n <- if (length(args) >= 4) as.integer(args[4]) else 50L
  full_verify_below_mb <- if (length(args) >= 5) as.numeric(args[5]) else 50
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# 2. Locate manifest --------------------------------------------------------------
manifest_matches <- list.files(target_dir, pattern = paste0("^", manifest_name, "$"),
                                recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
if (length(manifest_matches) == 0) {
  message(sprintf("No file named '%s' found under %s. Exiting.", manifest_name, target_dir))
  quit(status = 0)
}
manifest_path <- manifest_matches[1]
manifest_dir <- dirname(manifest_path)
message(paste("Using manifest:", manifest_path))

# 3. Parse manifest -----------------------------------------------------------------
# Accepts "<hex>  <path>" or "<hex> *<path>" (binary-mode marker), one or two spaces.
manifest_lines <- readLines(manifest_path, warn = FALSE)
manifest_lines <- manifest_lines[trimws(manifest_lines) != ""]

parse_line <- function(line) {
  m <- str_match(line, "^([0-9a-fA-F]{32,64})\\s+\\*?(.+)$")
  if (is.na(m[1, 1])) return(tibble(Hash = NA_character_, Path = NA_character_))
  tibble(Hash = tolower(m[1, 2]), Path = str_trim(m[1, 3]))
}
manifest <- map_dfr(manifest_lines, parse_line) %>% filter(!is.na(Hash))
manifest$Path <- gsub("\\\\", "/", manifest$Path)

# Hash algorithm inferred from digest length (sha256 = 64 hex chars, md5 = 32)
algo <- if (nrow(manifest) > 0 && nchar(manifest$Hash[1]) == 32) "md5" else "sha256"

message(sprintf("Parsed %d manifest entries. Algorithm inferred: %s", nrow(manifest), algo))

if (nrow(manifest) == 0) {
  message("No parseable entries found in manifest. Exiting.")
  quit(status = 0)
}

# 4. Existence + size pass (cheap, always exhaustive) --------------------------------
manifest <- manifest %>%
  mutate(
    Full_Path = file.path(manifest_dir, Path),
    Exists = file.exists(Full_Path),
    Size_Bytes = ifelse(Exists, file.size(Full_Path), NA_real_),
    Size_MB = round(Size_Bytes / 1024^2, 2)
  )

n_missing <- sum(!manifest$Exists)
message(sprintf("Existence check: %d/%d files present on disk.", sum(manifest$Exists), nrow(manifest)))
if (n_missing > 0) message(sprintf("WARNING: %d file(s) listed in the manifest are missing from disk.", n_missing))

# 5. Select which present files get a full hash verification -------------------------
present <- manifest %>% filter(Exists)
small <- present %>% filter(Size_MB <= full_verify_below_mb)
large <- present %>% filter(Size_MB > full_verify_below_mb)

set.seed(42)  # reproducible sample selection, not a security-relevant seed
sample_large <- if (nrow(large) > sample_n) large %>% slice_sample(n = sample_n) else large

to_verify <- bind_rows(small, sample_large)
message(sprintf("Full-hash verification: %d file(s) at/under %g MB (all of them) + %d/%d larger file(s) sampled = %d file(s) total.",
                 nrow(small), full_verify_below_mb, nrow(sample_large), nrow(large), nrow(to_verify)))

hash_file <- function(fp) {
  tryCatch(digest::digest(fp, algo = algo, file = TRUE), error = function(e) NA_character_)
}

message("Hashing selected files (this is the slow, I/O-bound step)...")
to_verify$Computed_Hash <- map_chr(to_verify$Full_Path, hash_file)
to_verify$Match <- tolower(to_verify$Computed_Hash) == to_verify$Hash

# 6. Assemble full report -----------------------------------------------------------
report <- manifest %>%
  left_join(to_verify %>% select(Path, Computed_Hash, Match), by = "Path") %>%
  mutate(
    Verification = case_when(
      !Exists ~ "MISSING FROM DISK",
      is.na(Match) ~ "Not sampled (existence/size only)",
      Match ~ "Hash verified: match",
      !Match ~ "HASH MISMATCH"
    )
  ) %>%
  select(Path, Size_MB, Verification, Manifest_Hash = Hash, Computed_Hash)

n_mismatch <- sum(report$Verification == "HASH MISMATCH", na.rm = TRUE)
n_verified_ok <- sum(report$Verification == "Hash verified: match", na.rm = TRUE)

# 7. Extra-file check: files on disk not listed in the manifest at all ----------------
disk_files <- list.files(manifest_dir, recursive = TRUE, full.names = FALSE)
disk_files <- disk_files[!grepl("Curation_Results", disk_files, ignore.case = TRUE)]
disk_files <- disk_files[basename(disk_files) != basename(manifest_path)]
orphans <- setdiff(gsub("\\\\", "/", disk_files), manifest$Path)

if (length(orphans) > 0) {
  orphan_report <- tibble(Path = orphans, Size_MB = NA, Verification = "ON DISK, NOT IN MANIFEST",
                           Manifest_Hash = NA_character_, Computed_Hash = NA_character_)
  report <- bind_rows(report, orphan_report)
}

# 8. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("ChecksumManifest_Verification_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("Path", "Size_MB", "Verification", "Manifest_Hash", "Computed_Hash"),
  Type = c("Text", "Numeric", "Text", "Text", "Text"),
  Description = c(
    "File path as listed in the manifest (relative to the manifest's own directory).",
    "File size in megabytes, if the file exists on disk.",
    'One of: "Hash verified: match" (fully re-hashed, matches), "HASH MISMATCH" (fully re-hashed, does NOT match — investigate immediately), "Not sampled (existence/size only)" (file exists, was not selected for full re-hashing this run), "MISSING FROM DISK" (listed in manifest, not found), "ON DISK, NOT IN MANIFEST" (present but undocumented by the manifest).',
    paste0("Digest from the manifest file (", algo, ")."),
    "Digest actually computed from the file on disk, if it was selected for verification; blank otherwise."
  )
)
codebook_file <- file.path(output_dir, "ChecksumManifest_Verification_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(sprintf("Process complete. %d verified matches, %d MISMATCHES, %d missing, %d orphaned (on disk, not in manifest).",
                 n_verified_ok, n_mismatch, n_missing, length(orphans)))
if (n_mismatch > 0) message("CRITICAL: at least one hash mismatch found — treat as a required action, do not publish until resolved.")
message(paste("Report saved to:", output_file))
