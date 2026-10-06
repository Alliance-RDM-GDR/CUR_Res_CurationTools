#!/usr/bin/env Rscript

# ==============================================================================
# Script: Redact_EyeLinkHeader_Script.R
# Purpose: Remove re-identifying metadata from the comment header of EyeLink
#          ASCII (.asc) eye-tracking files, before a dataset is published:
#            "** DATE: <session date and time>"          -> "** DATE: [removed]"
#            "** CONVERTED FROM <local path>\<name>.edf using <tool> [on <date>]"
#                 -> "** CONVERTED FROM [removed] using <tool>"
#          The local path can contain a user's name, the original recording
#          name (an internal participant/series code) and the session date;
#          the DATE line gives the exact recording time. Both are quasi-
#          identifiers: a session date can be matched against schedules or
#          records. Only these header comment lines (starting with "**") are
#          touched; every sample, event, message and calibration line after
#          the header is left byte for byte identical.
#
# IMPORTANT: Like Repair_TextEncoding_Script.R, and unlike the Inspect_*
#            scripts, this one WRITES to the target files. It refuses to modify
#            a file until an exact copy has been saved to <backup_dir> (same
#            relative path) and verified by MD5. Each modified file is then
#            re-read and checked: the body after the header must be identical
#            to the original and the header must contain no remaining date or
#            path. The log records only file names and pass/fail flags, never
#            the removed values.
#
# Usage:   Rscript Redact_EyeLinkHeader_Script.R <target_dir> <backup_dir> [log_dir] [file_pattern]
#          log_dir defaults to backup_dir; file_pattern defaults to "\\.asc$".
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript Redact_EyeLinkHeader_Script.R <target_dir> <backup_dir> [log_dir] [file_pattern]", call. = FALSE)
}
target_dir   <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
backup_dir   <- args[2]
log_dir      <- if (length(args) >= 3) args[3] else backup_dir
file_pattern <- if (length(args) >= 4) args[4] else "\\.asc$"

if (!dir.exists(backup_dir)) dir.create(backup_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(log_dir)) dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
backup_dir <- normalizePath(backup_dir, winslash = "/", mustWork = TRUE)
if (startsWith(backup_dir, target_dir)) {
  stop("backup_dir must be outside target_dir, or the backup would be rescanned as data.", call. = FALSE)
}

files <- list.files(target_dir, pattern = file_pattern, recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
files <- files[!grepl("Curation_Results", files, ignore.case = TRUE)]
message(sprintf("Found %d file(s) matching %s in %s", length(files), file_pattern, target_dir))
if (length(files) == 0) quit(status = 0)

# 1. Header handling -------------------------------------------------------------
# The header is the leading run of comment ("**") or blank lines.
split_header <- function(raw_bytes) {
  chunk <- raw_bytes[seq_len(min(length(raw_bytes), 16384))]
  txt <- rawToChar(chunk)
  Encoding(txt) <- "latin1"
  lines <- strsplit(txt, "(?<=\n)", perl = TRUE)[[1]]
  n_hdr <- 0L
  for (ln in lines) {
    core <- sub("\r?\n$", "", ln)
    if (grepl("^\\*\\*", core) || !nzchar(trimws(core))) n_hdr <- n_hdr + 1L else break
  }
  if (n_hdr == length(lines)) stop("could not find the end of the header within the first 16 KB")
  hdr_lines <- lines[seq_len(n_hdr)]
  list(lines = hdr_lines, bytes = sum(nchar(hdr_lines, type = "bytes")))
}

redact_line <- function(line) {
  eol  <- regmatches(line, regexpr("\r?\n$", line, perl = TRUE))
  if (length(eol) == 0) eol <- ""
  core <- sub("\r?\n$", "", line, perl = TRUE)
  if (grepl("^\\*\\* CONVERTED FROM ", core)) {
    tool <- if (grepl("^\\*\\* CONVERTED FROM .*? using ", core, perl = TRUE)) {
      sub("^\\*\\* CONVERTED FROM .*? (using .*)$", "\\1", core, perl = TRUE)
    } else ""
    tool <- sub(" on [A-Z][a-z]{2} [A-Z][a-z]{2} +[0-9]{1,2} [0-9:]{8} [0-9]{4}$", "", tool)
    core <- paste0("** CONVERTED FROM [removed]", if (nzchar(tool)) paste0(" ", tool) else "")
  } else if (grepl("^\\*\\* DATE:", core)) {
    core <- "** DATE: [removed]"
  }
  paste0(core, eol)
}

header_is_clean <- function(hdr_lines) {
  core <- sub("\r?\n$", "", hdr_lines)
  !any(grepl("^\\*\\* DATE:", core) & !grepl("^\\*\\* DATE: \\[removed\\]$", core)) &&
    !any(grepl("^\\*\\* CONVERTED FROM", core) & !grepl("^\\*\\* CONVERTED FROM \\[removed\\]", core)) &&
    !any(grepl("[A-Za-z]:\\\\", core))
}

# 2. Per-file processing ----------------------------------------------------------
process_file <- function(fp) {
  rel <- sub(paste0(target_dir, "/"), "", normalizePath(fp, winslash = "/"), fixed = TRUE)
  tryCatch({
    orig <- readBin(fp, what = "raw", n = file.size(fp))
    h <- split_header(orig)
    new_lines <- vapply(h$lines, redact_line, character(1), USE.NAMES = FALSE)
    n_changed <- sum(new_lines != h$lines)

    if (n_changed == 0) {
      return(tibble(File = rel, Header_Lines_Changed = 0L, Backup_Verified = NA, Body_Identical = NA,
                    Header_Clean = header_is_clean(h$lines), Status = "No change needed"))
    }

    # Backup first, and verify it, before touching the original.
    bk <- file.path(backup_dir, rel)
    dir.create(dirname(bk), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(fp, bk, overwrite = FALSE, copy.date = TRUE) && !file.exists(bk)) stop("backup copy failed")
    backup_ok <- identical(unname(tools::md5sum(fp)), unname(tools::md5sum(bk)))
    if (!backup_ok) {
      return(tibble(File = rel, Header_Lines_Changed = n_changed, Backup_Verified = FALSE, Body_Identical = NA,
                    Header_Clean = NA, Status = "SKIPPED: backup did not verify, original untouched"))
    }

    new_hdr_txt <- paste(new_lines, collapse = "")
    Encoding(new_hdr_txt) <- "latin1"
    body_orig <- orig[(h$bytes + 1):length(orig)]
    writeBin(c(charToRaw(new_hdr_txt), body_orig), fp)

    # Independent verification from disk.
    new_raw <- readBin(fp, what = "raw", n = file.size(fp))
    h2 <- split_header(new_raw)
    body_new <- new_raw[(h2$bytes + 1):length(new_raw)]
    body_ok <- identical(body_new, body_orig)
    clean <- header_is_clean(h2$lines)

    tibble(File = rel, Header_Lines_Changed = n_changed, Backup_Verified = TRUE, Body_Identical = body_ok,
           Header_Clean = clean, Status = if (body_ok && clean) "Success" else "CHECK: verification failed")
  }, error = function(e) {
    tibble(File = rel, Header_Lines_Changed = NA_integer_, Backup_Verified = NA, Body_Identical = NA,
           Header_Clean = NA, Status = paste("Failed:", conditionMessage(e)))
  })
}

# 3. Execution ---------------------------------------------------------------------
n <- length(files)
out <- vector("list", n)
for (i in seq_len(n)) {
  out[[i]] <- process_file(files[i])
  if (i %% 25 == 0 || i == n) message(sprintf("  %d / %d files processed", i, n))
}
log <- bind_rows(out)

log_file <- file.path(log_dir, paste0("EyeLink_Header_Redaction_Log_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"))
write_excel_csv(log, log_file)

message("Status summary:")
print(count(log, Status))
message(sprintf("Log saved to: %s", log_file))
if (any(!log$Status %in% c("Success", "No change needed"))) {
  message("WARNING: some files did not complete cleanly. Review the log before publishing.")
}
