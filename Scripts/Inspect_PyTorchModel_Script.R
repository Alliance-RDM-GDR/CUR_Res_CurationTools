#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_PyTorchModel_Script.R
# Purpose: Batch inspection of PyTorch model checkpoint files (.pt, .pth) for
#          archival/security review: file format (modern zip-based vs. legacy
#          pickle-only), and whether the file can be loaded with PyTorch's
#          safe `weights_only=True` mode.
#
# IMPORTANT — what this script deliberately does NOT do: it never loads a
#          checkpoint with `weights_only=False`. Doing so executes arbitrary
#          pickled Python objects from the file. A checkpoint that fails the
#          safe load is exactly the finding to report to the depositor
#          (distributing it means every downstream user must choose to trust
#          the file blindly, or inspect it manually themselves) — it is not
#          something this automated script should work around by trusting it.
#
# Requires: Python with the 'torch' package installed, reachable via
#           reticulate. Set RETICULATE_PYTHON to a specific interpreter path
#           if it is not the one reticulate would find automatically.
# Usage:   Rscript Inspect_PyTorchModel_Script.R <target_directory> [output_dir]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("Package 'reticulate' is required but not installed.")
  }
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
  output_dir <- file.path(getwd(), "Results/Inspect_PyTorchModel")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_PyTorchModel_Script.R /path/to/models [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_PyTorchModel")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

message(paste("Starting PyTorch checkpoint analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
model_files <- list.files(
  path = target_dir,
  pattern = "\\.(pt|pth)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
model_files <- model_files[!grepl("Curation_Results", model_files, ignore.case = TRUE)]

message(paste("Found", length(model_files), ".pt/.pth file(s)."))

if (length(model_files) == 0) {
  message("No PyTorch checkpoint files found. Exiting.")
  quit(status = 0)
}

# 3. Python setup ----------------------------------------------------------------
torch_available <- tryCatch({
  reticulate::py_run_string("import torch, zipfile")
  TRUE
}, error = function(e) {
  message("Could not import torch/zipfile via reticulate: ", conditionMessage(e))
  FALSE
})

if (!torch_available) {
  stop("Python 'torch' is required (via reticulate) but is not available. Set RETICULATE_PYTHON if needed.", call. = FALSE)
}

# 4. Processing Function -------------------------------------------------------
inspect_model <- function(fp) {
  fname <- basename(fp)
  file_size_mb <- round(file.size(fp) / 1024^2, 2)
  fp_py <- normalizePath(fp, winslash = "/", mustWork = TRUE)

  tryCatch({
    py_code <- sprintf('
import zipfile, torch

fp = r"""%s"""
is_zip_format = zipfile.is_zipfile(fp)

entry_count = None
if is_zip_format:
    with zipfile.ZipFile(fp) as z:
        entry_count = len(z.namelist())

safe_load_ok = False
safe_load_error = ""
try:
    torch.load(fp, weights_only=True, map_location="cpu")
    safe_load_ok = True
except Exception as e:
    safe_load_error = str(e).splitlines()[0][:200]
', fp_py)

    reticulate::py_run_string(py_code)
    py <- reticulate::py

    tibble(
      FileName = fname,
      Size_MB = file_size_mb,
      Is_Zip_Based_Format = isTRUE(py$is_zip_format),
      Internal_Entry_Count = if (is.null(py$entry_count)) NA_integer_ else as.integer(py$entry_count),
      Safe_Load_Possible = isTRUE(py$safe_load_ok),
      Safe_Load_Error = if (isTRUE(py$safe_load_ok)) "" else py$safe_load_error,
      Status = "Success"
    )
  }, error = function(e) {
    tibble(
      FileName = fname, Size_MB = file_size_mb, Is_Zip_Based_Format = NA,
      Internal_Entry_Count = NA, Safe_Load_Possible = NA, Safe_Load_Error = NA,
      Status = paste("Inspection Failed:", e$message)
    )
  })
}

# 5. Execution -----------------------------------------------------------------
message("Checking checkpoint format and safe-load status (weights_only=True only; never trusts the file by default)...")
report <- map_dfr(model_files, inspect_model)

# 6. Export ----------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("PyTorchModel_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "Size_MB", "Is_Zip_Based_Format", "Internal_Entry_Count",
               "Safe_Load_Possible", "Safe_Load_Error", "Status"),
  Type = c("Text", "Numeric", "Logical", "Integer", "Logical", "Text", "Text"),
  Description = c(
    "Name of the checkpoint file.",
    "File size in megabytes.",
    "TRUE if the file uses the modern zip-based PyTorch serialization format (introduced ~2020), as opposed to a legacy pickle-only file.",
    "Number of internal entries in the zip container (tensor data files plus the pickled object graph), if zip-based.",
    "TRUE if the checkpoint loads successfully with torch.load(weights_only=True) — PyTorch's restricted-unpickling safe mode. FALSE means the file embeds arbitrary Python objects and can only be loaded by choosing to trust the source (weights_only=False), which allows arbitrary code execution if the file is malicious.",
    "The error PyTorch raised under weights_only=True, when Safe_Load_Possible is FALSE.",
    'Either "Success" or "Inspection Failed: <error message>".'
  )
)
codebook_file <- file.path(output_dir, "PyTorchModel_Report_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(paste("Process complete. Report saved to:", output_file))
if (any(!report$Safe_Load_Possible, na.rm = TRUE)) {
  message("NOTE: one or more checkpoints cannot be safely loaded (require weights_only=False) — this is a standard Ultralytics/YOLO checkpoint behavior, but should be documented for reusers.")
}
