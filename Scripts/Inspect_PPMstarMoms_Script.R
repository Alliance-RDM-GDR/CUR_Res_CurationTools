#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_PPMstarMoms_Script.R
# Purpose: Content-level spot check of PPMstar "moms" 3-D cube files (the
#          headerless raw float32 payload described in a PPMstar release's
#          README and per-run variables.json). Where Inspect_PPMstarRelease_
#          Script.R checks structure (file counts, sizes) without opening the
#          payloads, this script actually reads a sample of them and reports
#          real per-variable statistics: min/max/mean, and NaN/Inf counts,
#          using the variable names/units/definitions from variables.json
#          rather than hardcoding them, so it stays correct if a future
#          PPMstar release documents a different variable set.
#
# Why sampling, not every file: a single moms file can be hundreds of MB to
# several GB, and a run can have thousands of them; reading everything is
# usually impractical within a review. This script reads a configurable
# number of dump-folders per run (default a handful) and one file per sampled
# dump, and says exactly which files it read — this is a spot check for
# plausibility (physically reasonable ranges, no unexpected Inf, NaN only
# where the release documents it as expected), not an exhaustive validation.
#
# File layout assumed (per the PPMstar release convention; see the header
# comment in Inspect_PPMstarRelease_Script.R for the evidence this is shared
# across releases, not specific to one submission):
#   <run>/variables.json                    variable names/units/order
#   <run>/moms/myavsbq/<dump>/<file>         one or more sub-cube files per dump,
#                                            each a raw little-endian float32
#                                            stream: N_VARS x (edge)^3 values,
#                                            variable-major (each variable's
#                                            values are one contiguous block)
#
# Usage:   Rscript Inspect_PPMstarMoms_Script.R <release_directory> [output_dir] [dumps_per_run] [seed]
#          dumps_per_run defaults to 3; seed (for reproducible sampling) defaults to 42.
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select PPMstar Release Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_PPMstarMoms")
  dumps_per_run <- 3L
  seed <- 42L
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_PPMstarMoms_Script.R /path/to/release_dir [output_dir] [dumps_per_run] [seed]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_PPMstarMoms")
  dumps_per_run <- if (length(args) >= 3) as.integer(args[3]) else 3L
  seed <- if (length(args) >= 4) as.integer(args[4]) else 42L
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# 2. Locate runs: any subdirectory directly under target_dir with a variables.json
run_dirs <- list.dirs(target_dir, recursive = FALSE)
run_dirs <- run_dirs[!grepl("Curation_Results", run_dirs, ignore.case = TRUE)]
run_dirs <- run_dirs[file.exists(file.path(run_dirs, "variables.json"))]

message(sprintf("Found %d run(s) with a variables.json.", length(run_dirs)))
if (length(run_dirs) == 0) {
  message("No runs found. Exiting.")
  quit(status = 0)
}

set.seed(seed)

# 3. Per-run sampling and content read --------------------------------------------
inspect_run <- function(run_dir) {
  run_name <- basename(run_dir)
  varjson <- tryCatch(fromJSON(file.path(run_dir, "variables.json"), simplifyDataFrame = FALSE),
                       error = function(e) NULL)
  if (is.null(varjson)) {
    return(tibble(Run = run_name, Dump = NA_character_, File = NA_character_,
                   Variable_Index = NA_integer_, Variable_Name = NA_character_, Units = NA_character_,
                   Min = NA_real_, Max = NA_real_, Mean = NA_real_, N_NaN = NA_integer_, N_Inf = NA_integer_,
                   N_Values = NA_integer_, Status = "Failed: variables.json did not parse"))
  }

  variables <- varjson$variables
  n_vars <- length(variables)
  edge <- varjson$sub_cube_with_ghosts
  if (is.null(edge) || is.null(n_vars) || n_vars == 0) {
    return(tibble(Run = run_name, Dump = NA_character_, File = NA_character_,
                   Variable_Index = NA_integer_, Variable_Name = NA_character_, Units = NA_character_,
                   Min = NA_real_, Max = NA_real_, Mean = NA_real_, N_NaN = NA_integer_, N_Inf = NA_integer_,
                   N_Values = NA_integer_, Status = "Failed: variables.json missing 'variables' or 'sub_cube_with_ghosts'"))
  }
  values_per_var <- edge^3

  moms_dir <- file.path(run_dir, "moms", "myavsbq")
  if (!dir.exists(moms_dir)) {
    return(tibble(Run = run_name, Dump = NA_character_, File = NA_character_,
                   Variable_Index = NA_integer_, Variable_Name = NA_character_, Units = NA_character_,
                   Min = NA_real_, Max = NA_real_, Mean = NA_real_, N_NaN = NA_integer_, N_Inf = NA_integer_,
                   N_Values = NA_integer_, Status = "Failed: no moms/myavsbq directory"))
  }

  dump_dirs <- list.dirs(moms_dir, recursive = FALSE)
  if (length(dump_dirs) == 0) {
    return(tibble(Run = run_name, Dump = NA_character_, File = NA_character_,
                   Variable_Index = NA_integer_, Variable_Name = NA_character_, Units = NA_character_,
                   Min = NA_real_, Max = NA_real_, Mean = NA_real_, N_NaN = NA_integer_, N_Inf = NA_integer_,
                   N_Values = NA_integer_, Status = "Failed: no dump folders found under moms/myavsbq"))
  }
  sampled_dumps <- if (length(dump_dirs) > dumps_per_run) sample(dump_dirs, dumps_per_run) else dump_dirs

  read_one_file <- function(fp, dump_label) {
    tryCatch({
      n_total <- values_per_var * n_vars
      vals <- readBin(fp, what = "numeric", n = n_total, size = 4, endian = "little")
      if (length(vals) != n_total) {
        return(tibble(Run = run_name, Dump = dump_label, File = basename(fp),
                       Variable_Index = NA_integer_, Variable_Name = NA_character_, Units = NA_character_,
                       Min = NA_real_, Max = NA_real_, Mean = NA_real_, N_NaN = NA_integer_, N_Inf = NA_integer_,
                       N_Values = length(vals),
                       Status = sprintf("Failed: read %d values, expected %d (file size does not match variables.json)", length(vals), n_total)))
      }
      map_dfr(seq_len(n_vars), function(v) {
        block <- vals[((v - 1) * values_per_var + 1):(v * values_per_var)]
        finite_block <- block[is.finite(block)]
        var_info <- variables[[v]]
        tibble(
          Run = run_name, Dump = dump_label, File = basename(fp),
          Variable_Index = var_info$index %||% (v - 1),
          Variable_Name = var_info$name %||% paste0("var", v - 1),
          Units = var_info$units %||% NA_character_,
          Min = if (length(finite_block) > 0) min(finite_block) else NA_real_,
          Max = if (length(finite_block) > 0) max(finite_block) else NA_real_,
          Mean = if (length(finite_block) > 0) mean(finite_block) else NA_real_,
          N_NaN = sum(is.nan(block)),
          N_Inf = sum(is.infinite(block)),
          N_Values = length(block),
          Status = "Success"
        )
      })
    }, error = function(e) {
      tibble(Run = run_name, Dump = dump_label, File = basename(fp),
             Variable_Index = NA_integer_, Variable_Name = NA_character_, Units = NA_character_,
             Min = NA_real_, Max = NA_real_, Mean = NA_real_, N_NaN = NA_integer_, N_Inf = NA_integer_,
             N_Values = NA_integer_, Status = paste("Failed:", e$message))
    })
  }

  `%||%` <- function(a, b) if (is.null(a)) b else a

  map_dfr(sampled_dumps, function(dd) {
    files_in_dump <- list.files(dd, full.names = TRUE)
    if (length(files_in_dump) == 0) return(NULL)
    f <- files_in_dump[1]  # one sub-cube file is enough for a plausibility spot check
    message(sprintf("  Reading %s ...", f))
    read_one_file(f, basename(dd))
  })
}

message("Sampling and reading moms cube files (this reads real data, may take a moment per file)...")
report <- map_dfr(run_dirs, inspect_run)

# 4. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("PPMstarMoms_ContentCheck_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("Run", "Dump", "File", "Variable_Index", "Variable_Name", "Units",
               "Min", "Max", "Mean", "N_NaN", "N_Inf", "N_Values", "Status"),
  Type = c("Text", "Text", "Text", "Integer", "Text", "Text",
           "Numeric", "Numeric", "Numeric", "Integer", "Integer", "Integer", "Text"),
  Description = c(
    "Run/subfolder name.",
    "Dump folder name this file was sampled from.",
    "Sub-cube file name actually read (one file per sampled dump, not every sub-cube).",
    "Variable index, from variables.json (0-based, as documented).",
    "Variable name, from variables.json.",
    "Variable units, from variables.json.",
    "Minimum finite value found for this variable in this file.",
    "Maximum finite value found for this variable in this file.",
    "Mean of finite values for this variable in this file.",
    "Count of NaN values for this variable in this file (variables.json / the README may document where NaN is expected, e.g. near-vacuum outer radial bins).",
    "Count of Inf/-Inf values (never expected; any non-zero count here is worth investigating).",
    "Total values read for this variable in this file (edge^3, ghosts included).",
    'Either "Success" or a "Failed: <reason>" message, e.g. a file whose size does not match what variables.json implies.'
  )
)
codebook_file <- file.path(output_dir, "PPMstarMoms_ContentCheck_Codebook.csv")
write_excel_csv(codebook, codebook_file)

n_inf <- sum(report$N_Inf > 0, na.rm = TRUE)
message(sprintf("Process complete. %d file(s) sampled across %d run(s).",
                 length(unique(paste(report$Run, report$File))), length(unique(report$Run))))
if (n_inf > 0) message(sprintf("WARNING: %d variable/file combination(s) contain Inf values, which is never expected. Investigate.", n_inf))
message(paste("Report saved to:", output_file))
message("Reminder: this is a sample, not exhaustive. It confirms plausibility on the files actually read, not the whole release.")
