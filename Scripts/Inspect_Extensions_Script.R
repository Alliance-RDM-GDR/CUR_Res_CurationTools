#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_Extensions_Script.R
# Description: Generates a full file inventory with ExifTool metadata.
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(tools)
  # We load exiftoolr safely; if not installed, the script will handle it later
  if (requireNamespace("exiftoolr", quietly = TRUE)) {
    library(exiftoolr)
  }
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Usage: Rscript Inspect_Extensions_Script.R <input_dir> [output_dir]", call. = FALSE)
}

target_dir <- args[1]
# If output directory is provided, use it; otherwise default to "Results" in current WD
output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results")

if (!dir.exists(target_dir)) {
  stop(paste("Input directory does not exist:", target_dir))
}

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

message(sprintf("Inventorying directory: %s", target_dir))
message(sprintf("Results will be saved to: %s", output_dir))


# ------------------------------------------------------------------------------
# 2. Basic Inventory (The Triage Phase)
# ------------------------------------------------------------------------------
message("Scanning files...")

all_files <- list.files(
  path = target_dir,
  recursive = TRUE,
  full.names = TRUE,
  all.files = TRUE
)

message(sprintf("Found %d total files.", length(all_files)))

if (length(all_files) > 0) {
  
  # Build Base Inventory
  inventory <- tibble(FullPath = all_files) %>%
    mutate(
      FileName = basename(FullPath),
      RelativePath = str_remove(FullPath, paste0(target_dir, "/?")),
      
      # Extension normalization
      Extension = tolower(file_ext(FileName)),
      Extension = if_else(Extension == "", "(no extension)", paste0(".", Extension)),
      
      Size_Bytes = file.size(FullPath),
      Size_MB = round(Size_Bytes / 1024^2, 4)
    )
  
  # Apply Risk Flags
  junk_patterns <- c("\\.ds_store", "thumbs\\.db", "__macosx")
  exec_patterns <- c("\\.exe$", "\\.bat$", "\\.sh$", "\\.bin$", "\\.jar$")
  
  inventory <- inventory %>%
    mutate(
      Risk_Flag = case_when(
        Size_Bytes == 0 ~ "Zero-Byte File",
        str_detect(tolower(FileName), paste(junk_patterns, collapse = "|")) ~ "System Junk",
        str_detect(tolower(FileName), paste(exec_patterns, collapse = "|")) ~ "Executable",
        TRUE ~ "Clean"
      )
    )
  
  # ----------------------------------------------------------------------------
  # 3. Deep Metadata Extraction (ExifTool)
  # ----------------------------------------------------------------------------
  
  # Check if package is loaded AND if the external tool is actually installed
  has_exiftool <- requireNamespace("exiftoolr", quietly = TRUE) && !is.null(exiftoolr::exif_version())
  
  if (has_exiftool) {
    message("ExifTool detected. Extracting deep metadata (MIME types, Authors, Warnings)...")
    
    tryCatch({
      # We ask for specific tags to keep the process efficient
      tags_to_extract <- c("MIMEType", "FileType", "Author", "CreateDate", "Warning")
      
      # Run ExifTool (this handles batching internally)
      exif_data <- exiftoolr::exif_read(inventory$FullPath, tags = tags_to_extract)
      
      # Clean up results
      # ExifTool returns 'SourceFile' which matches our 'FullPath'
      exif_data <- exif_data %>% 
        rename(FullPath = SourceFile)
      
      # Remove 'FileName' if ExifTool returned it, to avoid duplicate cols in join
      if ("FileName" %in% names(exif_data)) {
        exif_data <- select(exif_data, -FileName)
      }
      
      # Join with main inventory
      inventory <- left_join(inventory, exif_data, by = "FullPath")
      
    }, error = function(e) {
      message("Warning: ExifTool execution failed despite being detected.")
      message("Error details: ", e$message)
    })
    
  } else {
    message("----------------------------------------------------------------")
    message("NOTICE: ExifTool not found on this system.")
    message("Skipping deep metadata extraction.")
    message("To enable this feature, install 'perl' and the 'exiftoolr' R package.")
    message("----------------------------------------------------------------")
    
    # Add empty columns so the output format remains consistent
    inventory <- inventory %>%
      mutate(
        MIMEType = NA_character_,
        FileType = NA_character_,
        Author = NA_character_,
        Warning = NA_character_
      )
  }
  
  # ----------------------------------------------------------------------------
  # 4. Generate Summary & Save
  # ----------------------------------------------------------------------------
  
  # Summary Report
  summary_table <- inventory %>%
    count(Extension, MIMEType, Risk_Flag, name = "Count") %>%
    arrange(desc(Count)) %>%
    mutate(Percent = round(100 * Count / sum(Count), 2))
  
  # Define Output Paths
  summary_file <- file.path(output_dir, paste0("Format_Summary_HPC_", Sys.Date(), ".csv"))
  inventory_file <- file.path(output_dir, paste0("Full_Inventory_ExifTool_HPC_", Sys.Date(), ".csv"))
  
  # Save
  write_csv(summary_table, summary_file)
  write_csv(inventory, inventory_file)
  
  message("Analysis complete.")
  message(sprintf("Summary saved to: %s", summary_file))
  message(sprintf("Full Inventory saved to: %s", inventory_file))
  
} else {
  message("Directory is empty. No report generated.")
}