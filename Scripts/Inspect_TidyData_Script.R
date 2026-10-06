#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_TidyData_Script.R
# Purpose: Heuristic screen for tabular data submitted as CSV or Excel that
#          shows structural signs of NOT being tidy (Wickham's sense: one
#          variable per column, one observation per row, one kind of
#          observational unit per table), plus a format recommendation
#          (CSV preferred over Excel for FAIR/accessibility).
#
#          IMPORTANT: this is a heuristic RED-FLAG screen, not a tidy-data
#          verdict. A file with no flags below is not guaranteed to be tidy,
#          and a flagged file is not guaranteed to be wrong — every flag
#          still needs a human read to confirm the content and semantics. What
#          this script catches is limited to structural evidence: duplicate headers,
#          stacked data blocks under one header row, embedded blank
#          separator rows, and suspiciously wide column-name patterns.
# Usage:   Rscript Inspect_TidyData_Script.R <target_directory>
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(readxl)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Tabular Data Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_TidyData")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_TidyData_Script.R /path/to/tabular_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_TidyData")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting tidy-data heuristic screen on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
csv_files   <- list.files(target_dir, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
xlsx_files  <- list.files(target_dir, pattern = "\\.xls[xmb]?$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
csv_files   <- csv_files[!grepl("Curation_Results", csv_files, ignore.case = TRUE)]
xlsx_files  <- xlsx_files[!grepl("Curation_Results", xlsx_files, ignore.case = TRUE)]
# Exclude Excel's own hidden lock files (created while a workbook is open in
# Excel elsewhere) — not depositor content, and unreadable as data.
xlsx_files  <- xlsx_files[!grepl("^~\\$", basename(xlsx_files))]

message(sprintf("Found %d CSV and %d Excel file(s).", length(csv_files), length(xlsx_files)))

if (length(csv_files) == 0 && length(xlsx_files) == 0) {
  message("No tabular files found. Exiting.")
  quit(status = 0)
}

# 3. Heuristic checks on a single header + data-row matrix -----------------------
# `headers`: character vector of column names as they appear in row 1 (untouched,
# so duplicates are still visible). `raw_rows`: list of character vectors, one per
# subsequent row (as read without type coercion), same length as headers.
screen_table <- function(headers, raw_rows) {

  duplicate_headers <- headers[duplicated(headers) & !is.na(headers) & headers != ""]
  has_duplicate_headers <- length(duplicate_headers) > 0

  is_blank_row <- function(row) all(is.na(row) | trimws(row) == "")
  blank_row_flags <- map_lgl(raw_rows, is_blank_row)
  n_data_rows <- length(raw_rows)
  # A single blank row at the very end is normal EOF noise, not a structural issue —
  # only count blank rows that appear before the last row.
  embedded_blank_count <- if (n_data_rows > 1) sum(blank_row_flags[seq_len(n_data_rows - 1)]) else 0
  has_embedded_blank_rows <- embedded_blank_count > 0

  # Repeated header block: a later row whose values match the header row closely.
  header_norm <- tolower(trimws(headers))
  row_matches_header <- function(row) {
    row_norm <- tolower(trimws(as.character(row)))
    length(row_norm) == length(header_norm) &&
      mean(row_norm == header_norm, na.rm = TRUE) > 0.7
  }
  stacked_header_rows <- which(map_lgl(raw_rows, row_matches_header))
  has_stacked_tables <- length(stacked_header_rows) > 0

  # Wide-format suspicion: most column names look like years or dates, implying
  # a variable (e.g. "value") is spread across columns instead of held in one.
  year_like <- str_detect(trimws(headers), "^(19|20)\\d{2}$")
  date_like <- str_detect(trimws(headers), "^\\d{4}-\\d{2}(-\\d{2})?$")
  wide_suspect <- length(headers) > 3 && (mean(year_like) > 0.5 || mean(date_like) > 0.5)

  # Header hygiene: a column name should be directly usable as a variable name
  # (e.g. loadable into a tidy table) without renaming — no spaces, no special
  # characters that need quoting/escaping in common analysis software, not empty.
  clean_header_pattern <- "^[A-Za-z][A-Za-z0-9_.]*$"
  describe_header_issue <- function(h) {
    if (is.na(h) || trimws(h) == "") return("empty/unnamed column")
    if (grepl("^\\.\\.\\.\\d+$", h)) return("empty/unnamed column")
    if (str_detect(h, clean_header_pattern)) return(NA_character_)
    reasons <- c(
      if (str_detect(h, "\\s")) "contains space(s)",
      if (str_detect(h, "[^A-Za-z0-9_. ]")) "contains special character(s)"
    )
    if (length(reasons) == 0) reasons <- "not a clean variable-name format"
    paste0(h, " (", paste(reasons, collapse = ", "), ")")
  }
  header_issues <- purrr::map_chr(headers, describe_header_issue) %>% discard(is.na)
  has_header_issues <- length(header_issues) > 0

  tibble(
    Has_Duplicate_Headers = has_duplicate_headers,
    Duplicate_Header_Names = paste(unique(duplicate_headers), collapse = "; "),
    Has_Embedded_Blank_Rows = has_embedded_blank_rows,
    Embedded_Blank_Row_Count = embedded_blank_count,
    Has_Stacked_Header_Block = has_stacked_tables,
    Stacked_Header_Row_Numbers = paste(stacked_header_rows, collapse = "; "),
    Wide_Format_Suspect = wide_suspect,
    Has_Header_Hygiene_Issues = has_header_issues,
    Header_Hygiene_Issues = paste(header_issues, collapse = "; ")
  )
}

flag_summary <- function(row) {
  flags <- c(
    if (isTRUE(row$Has_Duplicate_Headers)) "DUPLICATE_HEADERS",
    if (isTRUE(row$Has_Embedded_Blank_Rows)) "EMBEDDED_BLANK_ROWS",
    if (isTRUE(row$Has_Stacked_Header_Block)) "POSSIBLE_STACKED_TABLES",
    if (isTRUE(row$Wide_Format_Suspect)) "POSSIBLE_WIDE_FORMAT",
    if (isTRUE(row$Has_Header_Hygiene_Issues)) "HEADER_HYGIENE_ISSUES"
  )
  if (length(flags) == 0) "None" else paste(flags, collapse = "; ")
}

# 3b. Delimiter Detection ---------------------------------------------------------
# A ".csv" file is not guaranteed to be comma-delimited (European/French-locale
# exports commonly use semicolons) — detect rather than assume, or a semicolon
# file silently reads as one column and every tidy check below is meaningless.
detect_delimiter <- function(file_path) {
  first_line <- tryCatch(readLines(file_path, n = 1, warn = FALSE), error = function(e) "")
  if (length(first_line) == 0) return(",")
  candidates <- c("," = ",", ";" = ";", "\t" = "\t", "|" = "|")
  counts <- purrr::map_int(candidates, ~ lengths(regmatches(first_line, gregexpr(.x, first_line, fixed = TRUE))))
  candidates[[which.max(counts)]]
}

# 4. Process CSV files -----------------------------------------------------------
process_csv <- function(fp) {
  fname <- basename(fp)
  tryCatch({
    # A CSV saved by Excel on Mac/Windows is often not UTF-8 (e.g. a per-mille
    # sign saved as a single byte). readr errors out on invalid UTF-8 ("Read
    # Failed: In index: N"), so fall back to Latin-1 for the screen; this only
    # affects how stray accented/symbol bytes display, not the structural checks.
    txt <- readLines(fp, warn = FALSE, encoding = "unknown")
    enc <- if (all(validUTF8(txt))) "UTF-8" else "latin1"
    raw <- readr::read_delim(fp, delim = detect_delimiter(fp), col_names = FALSE, col_types = cols(.default = "c"),
                            locale = readr::locale(encoding = enc),
                            show_col_types = FALSE, progress = FALSE)
    if (nrow(raw) == 0) {
      return(tibble(FileName = fname, Sheet = NA_character_, Format_Recommendation = "N/A (empty file)",
                     Has_Duplicate_Headers = NA, Duplicate_Header_Names = NA,
                     Has_Embedded_Blank_Rows = NA, Embedded_Blank_Row_Count = NA,
                     Has_Stacked_Header_Block = NA, Stacked_Header_Row_Numbers = NA,
                     Wide_Format_Suspect = NA, Flags = "N/A (empty file)", Status = "Empty"))
    }
    headers <- as.character(raw[1, ])
    raw_rows <- if (nrow(raw) > 1) purrr::map(2:nrow(raw), ~ as.character(raw[.x, ])) else list()
    result <- screen_table(headers, raw_rows)
    result$Flags <- flag_summary(result)
    result %>%
      mutate(FileName = fname, Sheet = NA_character_,
             Format_Recommendation = "Already CSV",
             Status = "Success") %>%
      select(FileName, Sheet, Format_Recommendation, everything())
  }, error = function(e) {
    tibble(FileName = fname, Sheet = NA_character_, Format_Recommendation = NA,
           Has_Duplicate_Headers = NA, Duplicate_Header_Names = NA,
           Has_Embedded_Blank_Rows = NA, Embedded_Blank_Row_Count = NA,
           Has_Stacked_Header_Block = NA, Stacked_Header_Row_Numbers = NA,
           Wide_Format_Suspect = NA, Flags = NA, Status = paste("Read Failed:", e$message))
  })
}

# 5. Process Excel files (per sheet) ----------------------------------------------
process_xlsx <- function(fp) {
  fname <- basename(fp)
  tryCatch({
    sheets <- readxl::excel_sheets(fp)
    map_dfr(sheets, function(sheet) {
      tryCatch({
        raw <- readxl::read_excel(fp, sheet = sheet, col_names = FALSE,
                                   col_types = "text", .name_repair = "minimal")
        if (nrow(raw) == 0) {
          return(tibble(FileName = fname, Sheet = sheet, Format_Recommendation = "N/A (empty sheet)",
                         Has_Duplicate_Headers = NA, Duplicate_Header_Names = NA,
                         Has_Embedded_Blank_Rows = NA, Embedded_Blank_Row_Count = NA,
                         Has_Stacked_Header_Block = NA, Stacked_Header_Row_Numbers = NA,
                         Wide_Format_Suspect = NA, Flags = "N/A (empty sheet)", Status = "Empty"))
        }
        headers <- as.character(raw[1, ])
        raw_rows <- if (nrow(raw) > 1) purrr::map(2:nrow(raw), ~ as.character(raw[.x, ])) else list()
        result <- screen_table(headers, raw_rows)
        result$Flags <- flag_summary(result)
        n_sheets <- length(sheets)
        rec <- if (n_sheets > 1) {
          sprintf("Convert to CSV (this workbook has %d sheets — export each as its own CSV)", n_sheets)
        } else {
          "Convert to CSV"
        }
        result %>%
          mutate(FileName = fname, Sheet = sheet, Format_Recommendation = rec,
                 Status = "Success") %>%
          select(FileName, Sheet, Format_Recommendation, everything())
      }, error = function(e) {
        tibble(FileName = fname, Sheet = sheet, Format_Recommendation = NA,
               Has_Duplicate_Headers = NA, Duplicate_Header_Names = NA,
               Has_Embedded_Blank_Rows = NA, Embedded_Blank_Row_Count = NA,
               Has_Stacked_Header_Block = NA, Stacked_Header_Row_Numbers = NA,
               Wide_Format_Suspect = NA, Flags = NA, Status = paste("Read Failed:", e$message))
      })
    })
  }, error = function(e) {
    tibble(FileName = fname, Sheet = NA_character_, Format_Recommendation = NA,
           Has_Duplicate_Headers = NA, Duplicate_Header_Names = NA,
           Has_Embedded_Blank_Rows = NA, Embedded_Blank_Row_Count = NA,
           Has_Stacked_Header_Block = NA, Stacked_Header_Row_Numbers = NA,
           Wide_Format_Suspect = NA, Flags = NA, Status = paste("File Failed:", e$message))
  })
}

# 6. Execution -----------------------------------------------------------------
message("Screening CSV files...")
csv_report <- map_dfr(csv_files, process_csv)

message("Screening Excel files (sheet by sheet)...")
xlsx_report <- map_dfr(xlsx_files, process_xlsx)

report <- bind_rows(csv_report, xlsx_report)

# 7. Export ----------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("TidyData_Screen_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "Sheet", "Format_Recommendation", "Has_Duplicate_Headers",
               "Duplicate_Header_Names", "Has_Embedded_Blank_Rows", "Embedded_Blank_Row_Count",
               "Has_Stacked_Header_Block", "Stacked_Header_Row_Numbers", "Wide_Format_Suspect",
               "Has_Header_Hygiene_Issues", "Header_Hygiene_Issues", "Flags", "Status"),
  Type = c("Text", "Text", "Text", "Logical", "Text", "Logical", "Integer",
           "Logical", "Text", "Logical", "Logical", "Text", "Text", "Text"),
  Description = c(
    "Name of the source file.",
    "Sheet name (Excel only; NA for CSV).",
    "Curation recommendation on file format (CSV already preferred, or a suggestion to convert from Excel).",
    "TRUE if the header row contains repeated column names.",
    "Which header name(s) are duplicated, if any.",
    "TRUE if a fully-blank row was found before the last row of the table (not counting a single trailing blank).",
    "Count of embedded (non-trailing) fully-blank rows.",
    "TRUE if a later row's values closely match the header row, suggesting a second data block was appended under the same headers instead of being a separate table.",
    "Row number(s) where a repeated header-like row was found.",
    "TRUE if more than half the column names look like bare years (e.g. 2020) or dates, suggesting a variable may be spread across columns (wide format) rather than held in one column.",
    "TRUE if one or more column names contain spaces, special characters, or are otherwise not directly usable as a variable name (e.g. in R, Python, or SQL) without renaming.",
    "Which header name(s) have hygiene issues, and why (space, special character, or empty/unnamed column), semicolon-separated.",
    "Semicolon-separated list of the flags raised above, or \"None\".",
    'Either "Success", "Empty", or "Read Failed: <error message>".'
  )
)
codebook_file <- file.path(output_dir, "TidyData_Screen_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(paste("Process complete. Report saved to:", output_file))
message("REMINDER: this is a heuristic screen, not a tidy-data verdict — confirm every flag by reading the file.")
