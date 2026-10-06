#!/usr/bin/env Rscript

# ==============================================================================
# Script: Repair_TextEncoding_Script.R
# Purpose: Detect and repair common text-encoding problems in plain-text files
#          (README.txt and similar): non-UTF-8 encoding, "mojibake" from
#          double-encoding (UTF-8 bytes mis-decoded as Windows-1252 and saved
#          again), and old Mac-style (CR-only) line endings.
#
# IMPORTANT: Unlike the Inspect_* scripts, this one WRITES to the target
#            files. Every file it touches is backed up first (unmodified copy,
#            suffixed "_original_backup.txt", written to output_dir) before
#            being overwritten. Review the change report before trusting it
#            blindly on anything you have not also eyeballed.
#
# Usage:   Rscript Repair_TextEncoding_Script.R <target_directory> [output_dir] [file_pattern]
#          file_pattern defaults to "\\.txt$" (case-insensitive).
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Repair_TextEncoding")
  file_pattern <- "\\.txt$"
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Repair_TextEncoding_Script.R /path/to/dataset [output_dir] [file_pattern]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Repair_TextEncoding")
  file_pattern <- if (length(args) >= 3) args[3] else "\\.txt$"
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Scanning for text files to check/repair in:", target_dir))

# 2. Inventory -----------------------------------------------------------------
text_files <- list.files(
  path = target_dir,
  pattern = file_pattern,
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
text_files <- text_files[!grepl("Curation_Results", text_files, ignore.case = TRUE)]
text_files <- text_files[!grepl("_original_backup", text_files, ignore.case = TRUE)]

message(paste("Found", length(text_files), "file(s) to check."))

if (length(text_files) == 0) {
  message("No matching files found. Exiting.")
  quit(status = 0)
}

# 3. Mojibake repair (double-encoding round-trip fix) ----------------------------
# Common tell: UTF-8 bytes for an accented character get individually
# mis-decoded as Windows-1252, producing 2-3 garbage characters in place of one
# (e.g. the UTF-8 bytes for "e2 80 93" (en dash) show up as the 3-character
# string "â€“"). Re-encoding that string AS IF it were
# Windows-1252 recovers the original UTF-8 byte sequence, which then decodes
# correctly back to the intended character.
mojibake_markers <- c(
  "Ã©", "Ã¨", "Ã ", "Ã´", "Ã§",
  "Ã¹", "Ãª", "Ã®", "Ã«", "Ã¯",
  "â€™", "â€œ", "â€",
  "â€“", "â€”", "â€¦",
  "Â°", "Â«", "Â»", "�"
)

count_markers <- function(x) {
  sum(vapply(mojibake_markers, function(m) {
    hits <- gregexpr(m, x, fixed = TRUE)[[1]]
    sum(hits > 0)
  }, numeric(1)))
}

try_fix_mojibake <- function(x) {
  tryCatch({
    bytes_as_cp1252 <- iconv(x, from = "UTF-8", to = "WINDOWS-1252", sub = "byte")
    fixed <- iconv(bytes_as_cp1252, from = "UTF-8", to = "UTF-8", sub = NA)
    if (is.na(fixed)) return(x)
    fixed
  }, error = function(e) x)
}

# 4. Processing Function -------------------------------------------------------
repair_file <- function(fp) {
  fname <- basename(fp)

  tryCatch({
    raw_bytes <- readBin(fp, what = "raw", n = file.info(fp)$size)

    # A. Determine source text encoding
    guess <- readr::guess_encoding(fp, n_max = 2000)
    detected_encoding <- if (nrow(guess) > 0) guess$encoding[1] else "UTF-8"

    raw_text <- rawToChar(raw_bytes)
    Encoding(raw_text) <- "bytes"

    was_already_utf8 <- toupper(detected_encoding) %in% c("UTF-8", "ASCII")
    decode_from <- if (was_already_utf8) "UTF-8" else detected_encoding
    text <- iconv(raw_text, from = decode_from, to = "UTF-8", sub = NA)
    if (is.na(text)) {
      # Fall back to Windows-1252, which is a superset of ASCII and rarely fails to decode
      text <- iconv(raw_text, from = "WINDOWS-1252", to = "UTF-8", sub = "byte")
    }

    encoding_changed <- !was_already_utf8

    # B. Mojibake (double-encoding) repair, applied LINE BY LINE.
    # A README can mix correctly-encoded text (e.g. pasted once, correctly) with
    # double-encoded text (pasted from a different, already-corrupted source) in
    # the same file. Running the round-trip fix on the whole document at once
    # risks corrupting an already-correct line elsewhere (re-encoding a genuine
    # accented character to Windows-1252 can produce a byte that is not valid
    # UTF-8 on its own, turning that line to NA and silently aborting the whole
    # repair). Fixing one line at a time means a failure on one line never
    # blocks a fix on another, and a correct line is never put at risk.
    markers_before <- count_markers(text)
    mojibake_fixed <- FALSE
    if (markers_before > 0) {
      text_lines <- strsplit(text, "\r\n|\n", perl = TRUE)[[1]]
      any_line_fixed <- FALSE
      text_lines <- purrr::map_chr(text_lines, function(line) {
        line_markers <- count_markers(line)
        if (line_markers == 0) return(line)
        candidate <- try_fix_mojibake(line)
        if (is.na(candidate)) return(line)
        if (count_markers(candidate) < line_markers) {
          any_line_fixed <<- TRUE
          return(candidate)
        }
        line
      })
      if (any_line_fixed) {
        line_ending <- if (grepl("\r\n", text, fixed = TRUE)) "\r\n" else "\n"
        text <- paste(text_lines, collapse = line_ending)
        mojibake_fixed <- TRUE
      }
    }

    # C. Line-ending normalization: old Mac-style CR-only -> CRLF.
    # Leave LF-only (Unix) and CRLF (Windows) files alone; both are widely supported.
    has_cr_only <- grepl("\r(?!\n)", text, perl = TRUE) && !grepl("\r\n", text, fixed = TRUE)
    if (has_cr_only) {
      text <- gsub("\r", "\r\n", text)
    }

    any_change <- encoding_changed || mojibake_fixed || has_cr_only

    if (any_change) {
      backup_path <- file.path(output_dir, paste0(tools::file_path_sans_ext(fname), "_original_backup.", tools::file_ext(fname)))
      writeBin(raw_bytes, backup_path)
      writeBin(charToRaw(text), fp)
    }

    tibble(
      FileName = fname,
      Detected_Encoding = detected_encoding,
      Encoding_Fixed = encoding_changed,
      Mojibake_Markers_Found = markers_before,
      Mojibake_Fixed = mojibake_fixed,
      CR_Only_Line_Endings_Fixed = has_cr_only,
      Any_Change_Made = any_change,
      Backup_Location = if (any_change) file.path(output_dir, paste0(tools::file_path_sans_ext(fname), "_original_backup.", tools::file_ext(fname))) else NA_character_,
      Status = "Success"
    )

  }, error = function(e) {
    tibble(
      FileName = fname, Detected_Encoding = NA, Encoding_Fixed = NA,
      Mojibake_Markers_Found = NA, Mojibake_Fixed = NA,
      CR_Only_Line_Endings_Fixed = NA, Any_Change_Made = NA, Backup_Location = NA,
      Status = paste("Failed:", e$message)
    )
  })
}

# 5. Execution -----------------------------------------------------------------
message("Checking and repairing text encoding issues...")
report <- map_dfr(text_files, repair_file)

# 6. Export ----------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("TextEncoding_Repair_Log_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "Detected_Encoding", "Encoding_Fixed", "Mojibake_Markers_Found",
               "Mojibake_Fixed", "CR_Only_Line_Endings_Fixed", "Any_Change_Made",
               "Backup_Location", "Status"),
  Type = c("Text", "Text", "Logical", "Integer", "Logical", "Logical", "Logical", "Text", "Text"),
  Description = c(
    "Name of the file checked.",
    "Encoding detected via readr::guess_encoding() before any repair.",
    "TRUE if the file was not already UTF-8/ASCII and was converted.",
    "Count of known double-encoding (mojibake) artifact sequences found before repair.",
    "TRUE if a mojibake repair pass was applied (only applied when it demonstrably reduced artifact count).",
    "TRUE if old Mac-style CR-only line endings were normalized to CRLF.",
    "TRUE if the file on disk was modified in any way.",
    "Path to the untouched original, saved before any modification; NA if no change was made.",
    'Either "Success" or "Failed: <error message>".'
  )
)
codebook_file <- file.path(output_dir, "TextEncoding_Repair_Log_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(paste("Process complete. Log saved to:", output_file))
message("REVIEW every row with Any_Change_Made = TRUE against its backup before trusting it, especially Mojibake_Fixed cases.")
