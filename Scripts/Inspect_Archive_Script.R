#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Archive_Script.R
# Purpose: Audit the CONTENTS of .zip/.rar archives without fully extracting
#          them (fast, even for multi-GB archives) — lists entry count, total
#          uncompressed size, top-level folder names, and flags junk/artifact
#          files that shouldn't be distributed (OS junk, framework cache
#          files, nested archives, bundled executables).
# Requires: for .rar files, UnRAR.exe (WinRAR) or unrar must be available —
#           set RAR_TOOL_PATH to its full path if not on PATH. .zip files use
#           base R's unzip(), no external dependency.
# Usage:   Rscript Inspect_Archive_Script.R <target_directory> [output_dir]
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
  output_dir <- file.path(getwd(), "Results/Inspect_Archive")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_Archive_Script.R /path/to/dataset [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_Archive")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# Locate a RAR listing tool: env var override, PATH, or common Windows install paths.
find_rar_tool <- function() {
  env_path <- Sys.getenv("RAR_TOOL_PATH", unset = "")
  if (nzchar(env_path) && file.exists(env_path)) return(env_path)
  on_path <- Sys.which(c("unrar", "UnRAR", "unrar.exe"))
  on_path <- on_path[nzchar(on_path)]
  if (length(on_path) > 0) return(on_path[1])
  common_paths <- c(
    "C:/Program Files/WinRAR/UnRAR.exe",
    "C:/Program Files (x86)/WinRAR/UnRAR.exe"
  )
  found <- common_paths[file.exists(common_paths)]
  if (length(found) > 0) return(found[1])
  NA_character_
}
rar_tool <- find_rar_tool()

message(paste("Scanning for archives in:", target_dir))

# 2. Inventory -----------------------------------------------------------------
archive_files <- list.files(
  path = target_dir,
  pattern = "\\.(zip|rar)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
archive_files <- archive_files[!grepl("Curation_Results", archive_files, ignore.case = TRUE)]

message(paste("Found", length(archive_files), "archive file(s)."))

if (length(archive_files) == 0) {
  message("No .zip/.rar files found. Exiting.")
  quit(status = 0)
}

# 3. Junk/risk pattern definitions (mirrors Inspect_Extensions_Script.R) --------
junk_patterns <- c("\\.ds_store$", "thumbs\\.db$", "__macosx", "^~\\$", "\\.cache$")
exec_patterns <- c("\\.exe$", "\\.bat$", "\\.sh$", "\\.bin$", "\\.jar$", "\\.dll$", "\\.so$", "\\.dylib$", "\\.msi$")

classify_entry <- function(name) {
  lname <- tolower(name)
  if (str_detect(lname, "\\.(zip|rar|7z|tar|gz)$")) return("Nested Archive")
  if (str_detect(lname, paste(junk_patterns, collapse = "|"))) return("System Junk / Cache")
  if (str_detect(lname, paste(exec_patterns, collapse = "|"))) return("Executable")
  "Clean"
}

# 4. Listing Functions -----------------------------------------------------------
list_zip <- function(fp) {
  info <- utils::unzip(fp, list = TRUE)
  tibble(EntryName = info$Name, Uncompressed_Bytes = info$Length)
}

list_rar <- function(fp) {
  if (is.na(rar_tool)) {
    stop("No RAR listing tool found. Set RAR_TOOL_PATH to UnRAR's full path.")
  }
  # "lb" = bare listing (names only); technical listing adds sizes via -v
  out <- system2(rar_tool, c("v", shQuote(fp)), stdout = TRUE, stderr = FALSE)
  # Parse the fixed-width technical listing: lines with a leading attribute code
  data_lines <- out[str_detect(out, "^\\s*\\.\\.[A-Z.]{4,6}\\s+\\d+")]
  parsed <- str_match(data_lines, "^\\s*\\S+\\s+(\\d+)\\s+\\d+\\s+\\d+%.*\\s([0-9A-F]{8})\\s+(.*)$")
  if (all(is.na(parsed[, 1]))) {
    # Fallback: names only, no size info, if the technical listing format didn't match
    names_only <- system2(rar_tool, c("lb", shQuote(fp)), stdout = TRUE, stderr = FALSE)
    return(tibble(EntryName = names_only, Uncompressed_Bytes = NA_real_))
  }
  tibble(EntryName = parsed[, 4], Uncompressed_Bytes = as.numeric(parsed[, 2])) %>%
    filter(!is.na(EntryName))
}

# 5. Processing Function -------------------------------------------------------
# Accumulates one row per top-level folder/file per archive (size, entry count) —
# useful when deciding how to repackage an archive (e.g. one .zip per top-level
# folder instead of an arbitrary size-based split). Filled in by inspect_archive().
top_level_breakdown_rows <- list()

inspect_archive <- function(fp) {
  fname <- basename(fp)
  ext <- tolower(tools::file_ext(fp))
  file_size_mb <- round(file.size(fp) / 1024^2, 2)

  tryCatch({
    entries <- if (ext == "zip") list_zip(fp) else list_rar(fp)

    # Directory entries (trailing slash/backslash, or size 0 with no extension) aren't files
    is_dir_entry <- str_detect(entries$EntryName, "[/\\\\]$") |
      (!str_detect(basename(gsub("\\\\", "/", entries$EntryName)), "\\."))
    file_entries <- entries[!is_dir_entry, ]

    file_entries <- file_entries %>%
      mutate(Classification = map_chr(EntryName, classify_entry))

    top_level_dirs <- entries$EntryName %>%
      gsub("\\\\", "/", .) %>%
      str_extract("^[^/]+") %>%
      unique() %>%
      discard(is.na)

    # Per-top-level-folder size/count breakdown, recorded for the combined
    # Archive_TopLevel_Breakdown report (one row per top-level name per archive).
    file_entries_top <- file_entries %>%
      mutate(Top_Level_Name = gsub("\\\\", "/", EntryName) %>% str_extract("^[^/]+"))
    breakdown <- file_entries_top %>%
      filter(!is.na(Top_Level_Name)) %>%
      group_by(Top_Level_Name) %>%
      summarise(
        Entry_Count = n(),
        Uncompressed_MB = round(sum(Uncompressed_Bytes, na.rm = TRUE) / 1024^2, 2),
        .groups = "drop"
      ) %>%
      mutate(FileName = fname, .before = 1)
    top_level_breakdown_rows[[length(top_level_breakdown_rows) + 1]] <<- breakdown

    flagged <- file_entries %>% filter(Classification != "Clean")

    tibble(
      FileName = fname,
      Archive_Size_MB = file_size_mb,
      Entry_Count = nrow(file_entries),
      Total_Uncompressed_MB = round(sum(file_entries$Uncompressed_Bytes, na.rm = TRUE) / 1024^2, 2),
      Top_Level_Names = paste(head(top_level_dirs, 10), collapse = "; "),
      Flagged_Entry_Count = nrow(flagged),
      Flagged_Entries_Preview = paste(head(flagged$EntryName, 10), collapse = "; "),
      Status = "Success"
    )
  }, error = function(e) {
    tibble(
      FileName = fname, Archive_Size_MB = file_size_mb, Entry_Count = NA,
      Total_Uncompressed_MB = NA, Top_Level_Names = NA,
      Flagged_Entry_Count = NA, Flagged_Entries_Preview = NA,
      Status = paste("Failed:", e$message)
    )
  })
}

# 6. Execution -----------------------------------------------------------------
message("Listing archive contents (this reads archive headers only, not full extraction)...")
report <- map_dfr(archive_files, inspect_archive)

# 7. Export ----------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("Archive_Audit_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "Archive_Size_MB", "Entry_Count", "Total_Uncompressed_MB",
               "Top_Level_Names", "Flagged_Entry_Count", "Flagged_Entries_Preview", "Status"),
  Type = c("Text", "Numeric", "Integer", "Numeric", "Text", "Integer", "Text", "Text"),
  Description = c(
    "Name of the archive file.",
    "Compressed (on-disk) size of the archive in megabytes.",
    "Number of file entries (directories excluded).",
    "Sum of uncompressed sizes of all entries, in megabytes (NA for .rar if the technical listing could not be parsed).",
    "Up to 10 top-level folder/file names inside the archive, semicolon-separated — check these against what the README says the archive contains.",
    "Count of entries flagged as System Junk/Cache, Executable, or Nested Archive.",
    "Up to 10 flagged entry names/paths, semicolon-separated.",
    'Either "Success" or "Failed: <error message>" (e.g. no RAR tool available).'
  )
)
codebook_file <- file.path(output_dir, "Archive_Audit_Codebook.csv")
write_excel_csv(codebook, codebook_file)

# 8. Per-top-level-folder breakdown ----------------------------------------------
if (length(top_level_breakdown_rows) > 0) {
  breakdown_report <- bind_rows(top_level_breakdown_rows)
  breakdown_file <- file.path(output_dir, paste0("Archive_TopLevel_Breakdown_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
  write_excel_csv(breakdown_report, breakdown_file)

  breakdown_codebook <- tibble(
    Variable = c("FileName", "Top_Level_Name", "Entry_Count", "Uncompressed_MB"),
    Type = c("Text", "Text", "Integer", "Numeric"),
    Description = c(
      "Name of the archive file.",
      "A top-level folder or file name inside the archive.",
      "Number of file entries under that top-level name.",
      "Sum of uncompressed sizes under that top-level name, in megabytes (NA/0 for .rar if the technical listing could not be parsed)."
    )
  )
  breakdown_codebook_file <- file.path(output_dir, "Archive_TopLevel_Breakdown_Codebook.csv")
  write_excel_csv(breakdown_codebook, breakdown_codebook_file)

  message(paste("Per-top-level-folder breakdown saved to:", breakdown_file))
  message("Use this when deciding how to repackage an archive (e.g. one .zip per top-level folder instead of an arbitrary size-based split).")
}

message(paste("Process complete. Report saved to:", output_file))
if (any(report$Flagged_Entry_Count > 0, na.rm = TRUE)) {
  message("WARNING: one or more archives contain flagged entries (junk/cache/executable/nested archive) — review before publication.")
}
