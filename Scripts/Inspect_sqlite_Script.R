#!/usr/bin/env Rscript

# ------------------------------------------------------------------------------
# Script: Inspect_sqlite_Script.R
# Description: Batch inspection of SQLite databases (manifest, tables, and row counts).
#              Designed for Hybrid use (Interactive / HPC).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(DBI)
  library(RSQLite)
})

# ------------------------------------------------------------------------------
# 1. Directory Selection Logic
# ------------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select SQLite Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  output_dir <- file.path(getwd(), "Results/Inspect_sqlite")
} else {
  if (length(args) == 0) {
    stop("Usage: Rscript Inspect_sqlite_Script.R <input_dir> [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  output_dir <- if (length(args) >= 2) file.path(args[2], "Inspect_sqlite") else "Results/Inspect_sqlite"
}

if (!dir.exists(target_dir)) stop(paste("Directory not found:", target_dir))
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

message(sprintf("Inspecting SQLite databases in: %s", target_dir))

# ------------------------------------------------------------------------------
# 2. File Inventory
# ------------------------------------------------------------------------------
db_files <- list.files(
  path = target_dir, 
  pattern = "\\.(sqlite|db|sqlite3)$", 
  full.names = TRUE, 
  recursive = TRUE,
  ignore.case = TRUE
)

message(sprintf("Found %d SQLite database files.", length(db_files)))

if (length(db_files) == 0) {
  message("No SQLite databases found. Exiting.")
  quit(status = 0)
}

# ------------------------------------------------------------------------------
# 3. Processing Function
# ------------------------------------------------------------------------------
inspect_sqlite <- function(file_path) {
  fname <- basename(file_path)
  
  tryCatch({
    con <- dbConnect(SQLite(), file_path)
    on.exit(dbDisconnect(con))
    
    tables <- dbListTables(con)
    
    if (length(tables) == 0) {
      return(tibble(
        file = fname,
        table_name = NA_character_,
        columns = NA_character_,
        row_count = 0,
        Status = "Empty Database"
      ))
    }
    
    map_dfr(tables, function(tbl) {
      cols <- dbGetQuery(con, paste0("PRAGMA table_info(", tbl, ")"))
      row_count <- dbGetQuery(con, paste0("SELECT COUNT(*) as count FROM ", tbl))$count
      
      tibble(
        file = fname,
        table_name = tbl,
        columns = paste(cols$name, collapse = ", "),
        row_count = as.integer(row_count),
        Status = "Success"
      )
    })
    
  }, error = function(e) {
    tibble(
      file = fname,
      table_name = NA_character_,
      columns = NA_character_,
      row_count = as.integer(NA),
      Status = paste("Failed:", e$message)
    )
  })
}

# ------------------------------------------------------------------------------
# 4. Execution and Save
# ------------------------------------------------------------------------------
db_inventory <- map_dfr(db_files, inspect_sqlite)

timestamp <- format(Sys.Date(), "%Y%m%d")
output_file <- file.path(output_dir, paste0("Database_Manifest_", timestamp, ".csv"))

write.csv(db_inventory, output_file, row.names = FALSE)

message(sprintf("✅ Process Complete."))
message(sprintf("   Analyzed tables saved to: %s", output_file))
