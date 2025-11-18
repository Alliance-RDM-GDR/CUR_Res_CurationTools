#!/usr/bin/env Rscript

## ------------------------------------------------------------------
## MATLAB File (.mat) Inspector – CLI version for HPC
##
## Usage (on login node or inside a batch script):
##   Rscript matlab_inspector.R \
##       --target_dir /path/to/data \
##       --output_dir /path/to/output \
##       --max_full_numeric 1000000 \
##       --max_sample_numeric 100000
##
## The script:
##   1. Scans for .mat files in target_dir (recursively)
##   2. Builds a structural report (variables, types, dimensions)
##   3. Builds a content report (numeric ranges, factor examples, etc.)
##   4. Writes two CSV files into output_dir
## ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(hdf5r)
  library(R.matlab)
  library(dplyr)
  library(purrr)
  library(tibble)
})

## ----------------------------- ##
## 1. Parse command line args    ##
## ----------------------------- ##

args <- commandArgs(trailingOnly = TRUE)

# Simple argument parser: --key value
parse_args <- function(args) {
  res <- list()
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (startsWith(key, "--")) {
      k <- sub("^--", "", key)
      if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
        # flag, treat as TRUE
        res[[k]] <- TRUE
        i <- i + 1L
      } else {
        res[[k]] <- args[[i + 1L]]
        i <- i + 2L
      }
    } else {
      i <- i + 1L
    }
  }
  res
}

cli <- parse_args(args)

# Defaults
target_dir        <- if (!is.null(cli$target_dir)) cli$target_dir else "."
output_dir        <- if (!is.null(cli$output_dir)) cli$output_dir else "Results/FileOpen_mat"
max_full_numeric  <- if (!is.null(cli$max_full_numeric)) as.numeric(cli$max_full_numeric) else 1e6
max_sample_numeric<- if (!is.null(cli$max_sample_numeric)) as.numeric(cli$max_sample_numeric) else 1e5

set.seed(123)  # for reproducible sampling in summaries

cat("Target directory :", normalizePath(target_dir), "\n")
cat("Output directory :", normalizePath(output_dir, mustWork = FALSE), "\n")
cat("max_full_numeric :", max_full_numeric, "\n")
cat("max_sample_numeric :", max_sample_numeric, "\n\n")

## ----------------------------- ##
## 2. Helper functions           ##
## ----------------------------- ##

# Parse dims from numeric vector or "3000 x 180 x 180" string
parse_dims <- function(d) {
  if (is.null(d) || (length(d) == 1 && is.na(d))) {
    return(list(str = "-", n_dim = 0L, n_el = NA_integer_))
  }
  if (is.character(d)) {
    parts <- strsplit(d, "x|×")[[1]]
    parts <- trimws(parts)
    parts <- parts[parts != ""]
    nums  <- suppressWarnings(as.integer(parts))
    if (length(nums) == 0 || all(is.na(nums))) {
      return(list(str = d, n_dim = NA_integer_, n_el = NA_integer_))
    } else {
      return(list(
        str   = paste(nums, collapse = " x "),
        n_dim = length(nums),
        n_el  = as.integer(prod(nums))
      ))
    }
  }
  nums <- suppressWarnings(as.integer(d))
  nums <- nums[!is.na(nums)]
  if (length(nums) == 0) {
    return(list(str = "-", n_dim = 0L, n_el = NA_integer_))
  } else {
    return(list(
      str   = paste(nums, collapse = " x "),
      n_dim = length(nums),
      n_el  = as.integer(prod(nums))
    ))
  }
}

# Summarize an R object (from HDF5 or readMat)
summarise_object <- function(x, file_name, var_name, dims_info, format_label,
                             max_full_numeric, max_sample_numeric) {
  
  n_el <- dims_info$n_el
  base_class <- class(x)[1]
  
  summary_type  <- "unknown"
  min_val       <- NA_real_
  max_val       <- NA_real_
  mean_val      <- NA_real_
  sd_val        <- NA_real_
  prop_true     <- NA_real_
  n_unique      <- NA_integer_
  example_vals  <- NA_character_
  
  if (is.numeric(x) || is.integer(x)) {
    summary_type <- "numeric"
    if (is.null(n_el) || is.na(n_el)) n_el <- length(x)
    if (n_el <= max_full_numeric) {
      v <- as.numeric(x)
      min_val  <- suppressWarnings(min(v, na.rm = TRUE))
      max_val  <- suppressWarnings(max(v, na.rm = TRUE))
      mean_val <- suppressWarnings(mean(v, na.rm = TRUE))
      sd_val   <- suppressWarnings(sd(v, na.rm = TRUE))
    } else {
      # sample
      idx <- sample.int(n_el, size = min(max_sample_numeric, n_el))
      v <- as.numeric(x)[idx]
      summary_type <- "numeric (sampled)"
      min_val  <- suppressWarnings(min(v, na.rm = TRUE))
      max_val  <- suppressWarnings(max(v, na.rm = TRUE))
      mean_val <- suppressWarnings(mean(v, na.rm = TRUE))
      sd_val   <- suppressWarnings(sd(v, na.rm = TRUE))
    }
    
  } else if (is.logical(x)) {
    summary_type <- "logical"
    if (is.null(n_el) || is.na(n_el)) n_el <- length(x)
    prop_true <- mean(x, na.rm = TRUE)
    
  } else if (is.character(x)) {
    summary_type <- "character"
    if (is.null(n_el) || is.na(n_el)) n_el <- length(x)
    uniq <- unique(x)
    n_unique <- length(uniq)
    example_vals <- paste(head(uniq, 3), collapse = " | ")
    
  } else if (is.list(x)) {
    summary_type <- "list"
    n_el <- length(x)
    element_types <- unique(vapply(x, function(z) class(z)[1], character(1)))
    example_vals <- paste(head(element_types, 3), collapse = " | ")
    
  } else {
    summary_type <- base_class
  }
  
  tibble(
    FileName      = file_name,
    VariableName  = var_name,
    Format        = format_label,
    Class         = base_class,
    Dimensions    = dims_info$str,
    NumDimensions = dims_info$n_dim,
    NumElements   = n_el,
    SummaryType   = summary_type,
    Min           = min_val,
    Max           = max_val,
    Mean          = mean_val,
    SD            = sd_val,
    PropTrue      = prop_true,
    NUnique       = n_unique,
    ExampleValues = example_vals
  )
}

## ----------------------------- ##
## 3. Find .mat files            ##
## ----------------------------- ##

mat_files <- list.files(
  path        = target_dir,
  pattern     = "\\.mat$",
  recursive   = TRUE,
  full.names  = TRUE,
  ignore.case = TRUE
)

cat("Found", length(mat_files), ".mat files.\n")
if (length(mat_files) == 0L) {
  cat("Nothing to do. Exiting.\n")
  quit(status = 0L)
}
cat("Files:\n")
cat(paste("  -", mat_files), sep = "\n")
cat("\n")

## ------------------------------------------ ##
## 4. Structural report (per variable)        ##
## ------------------------------------------ ##

file_summary_list <- list()
var_summary_list  <- list()
idx <- 1L

for (file_path in mat_files) {
  file_name <- basename(file_path)
  cat("\n[STRUCT] Processing file:", file_name, "\n")
  
  file_size_mb <- round(file.info(file_path)$size / (1024^2), 3)
  
  # 4.1 HDF5 (v7.3) first
  res <- tryCatch({
    f <- H5File$new(file_path, mode = "r")
    on.exit(f$close_all(), add = TRUE)
    
    listing <- f$ls(recursive = TRUE)
    ds <- listing[listing$obj_type == "H5I_DATASET", , drop = FALSE]
    
    if (nrow(ds) == 0) stop("HDF5 file contains no datasets")
    
    dims_list <- ds$dataset.dims
    parsed <- lapply(dims_list, parse_dims)
    
    dims_str  <- vapply(parsed, function(x) x$str,   character(1))
    num_dims  <- vapply(parsed, function(x) x$n_dim, integer(1))
    num_elems <- vapply(parsed, function(x) x$n_el,  integer(1))
    
    tibble(
      FileName      = file_name,
      VariableName  = ds$name,
      Class         = as.character(ds$dataset.type_class),
      Dimensions    = dims_str,
      NumDimensions = num_dims,
      NumElements   = num_elems,
      Format        = "v7.3 (HDF5)"
    )
  }, error = function(e) {
    cat("  HDF5 structural read failed:", conditionMessage(e), "\n")
    NULL
  })
  
  # 4.2 Fallback: readMat (v4/v5)
  if (is.null(res)) {
    res <- tryCatch({
      mat_data  <- readMat(file_path)
      var_names <- names(mat_data)
      
      if (length(var_names) == 0) {
        cat("  readMat(): file appears empty.\n")
        tibble(
          FileName      = file_name,
          VariableName  = "(Empty)",
          Class         = "-",
          Dimensions    = "-",
          NumDimensions = 0L,
          NumElements   = NA_integer_,
          Format        = "v4/v5"
        )
      } else {
        cat("  readMat():", length(var_names), "variables.\n")
        map_dfr(var_names, function(var) {
          obj  <- mat_data[[var]]
          dims <- dim(obj)
          dims_info <- if (is.null(dims)) {
            list(str = paste(length(obj), "(len)"),
                 n_dim = if (length(obj) == 0) 0L else 1L,
                 n_el  = length(obj))
          } else {
            list(str = paste(as.integer(dims), collapse = " x "),
                 n_dim = length(dims),
                 n_el  = as.integer(prod(dims)))
          }
          tibble(
            FileName      = file_name,
            VariableName  = var,
            Class         = class(obj)[1],
            Dimensions    = dims_info$str,
            NumDimensions = dims_info$n_dim,
            NumElements   = dims_info$n_el,
            Format        = "v4/v5"
          )
        })
      }
    }, error = function(e) {
      cat("  readMat() structural read failed:", conditionMessage(e), "\n")
      tibble(
        FileName      = file_name,
        VariableName  = "ERROR",
        Class         = "Error",
        Dimensions    = paste("Failed to read:", conditionMessage(e)),
        NumDimensions = NA_integer_,
        NumElements   = NA_integer_,
        Format        = "Unknown"
      )
    })
  }
  
  file_summary_list[[idx]] <- tibble(
    FileName     = file_name,
    FullPath     = normalizePath(file_path),
    Format       = unique(res$Format)[1],
    FileSize_MB  = file_size_mb,
    NumVariables = nrow(res)
  )
  
  var_summary_list[[idx]] <- res
  idx <- idx + 1L
}

file_report <- bind_rows(file_summary_list)
mat_report  <- bind_rows(var_summary_list)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

struct_csv <- file.path(output_dir,
                        paste0("Matlab_Detailed_Report_", Sys.Date(), ".csv"))
write.csv(mat_report, struct_csv, row.names = FALSE)
cat("\nStructural report written to:", struct_csv, "\n")

file_csv <- file.path(output_dir,
                      paste0("Matlab_File_Summary_", Sys.Date(), ".csv"))
write.csv(file_report, file_csv, row.names = FALSE)
cat("File summary written to      :", file_csv, "\n")

## ------------------------------------------ ##
## 5. Content report (per variable summaries) ##
## ------------------------------------------ ##

content_summary_list <- list()
idx <- 1L

for (file_path in mat_files) {
  file_name <- basename(file_path)
  cat("\n[CONTENT] Processing file:", file_name, "\n")
  
  # 5.1 HDF5 (v7.3) first
  res <- tryCatch({
    f <- H5File$new(file_path, mode = "r")
    on.exit(f$close_all(), add = TRUE)
    
    listing <- f$ls(recursive = TRUE)
    ds <- listing[listing$obj_type == "H5I_DATASET", , drop = FALSE]
    
    if (nrow(ds) == 0) stop("HDF5 file contains no datasets")
    
    rows <- vector("list", nrow(ds))
    
    for (i in seq_len(nrow(ds))) {
      dset_name <- ds$name[i]
      cat("  Dataset:", dset_name, "\n")
      dset      <- f[[dset_name]]
      dims_info <- parse_dims(dset$dims)
      
      if (!is.na(dims_info$n_el) && dims_info$n_el > max_full_numeric * 10) {
        # Too large: metadata only
        rows[[i]] <- tibble(
          FileName      = file_name,
          VariableName  = dset_name,
          Format        = "v7.3 (HDF5)",
          Class         = as.character(ds$dataset.type_class[i]),
          Dimensions    = dims_info$str,
          NumDimensions = dims_info$n_dim,
          NumElements   = dims_info$n_el,
          SummaryType   = "too large to summarize",
          Min           = NA_real_,
          Max           = NA_real_,
          Mean          = NA_real_,
          SD            = NA_real_,
          PropTrue      = NA_real_,
          NUnique       = NA_integer_,
          ExampleValues = NA_character_
        )
      } else {
        x <- dset$read()
        rows[[i]] <- summarise_object(
          x             = x,
          file_name     = file_name,
          var_name      = dset_name,
          dims_info     = dims_info,
          format_label  = "v7.3 (HDF5)",
          max_full_numeric   = max_full_numeric,
          max_sample_numeric = max_sample_numeric
        )
      }
    }
    
    bind_rows(rows)
  }, error = function(e) {
    cat("  HDF5 content read failed:", conditionMessage(e), "\n")
    NULL
  })
  
  # 5.2 Fallback: readMat (v4/v5)
  if (is.null(res)) {
    res <- tryCatch({
      mat_data  <- readMat(file_path)
      var_names <- names(mat_data)
      
      if (length(var_names) == 0) {
        tibble(
          FileName      = file_name,
          VariableName  = "(Empty)",
          Format        = "v4/v5",
          Class         = "-",
          Dimensions    = "-",
          NumDimensions = 0L,
          NumElements   = NA_integer_,
          SummaryType   = "empty file",
          Min           = NA_real_,
          Max           = NA_real_,
          Mean          = NA_real_,
          SD            = NA_real_,
          PropTrue      = NA_real_,
          NUnique       = NA_integer_,
          ExampleValues = NA_character_
        )
      } else {
        rows <- vector("list", length(var_names))
        for (i in seq_along(var_names)) {
          var <- var_names[i]
          cat("  Variable:", var, "\n")
          obj <- mat_data[[var]]
          dims <- dim(obj)
          dims_info <- if (is.null(dims)) {
            list(str = paste(length(obj), "(len)"),
                 n_dim = if (length(obj) == 0) 0L else 1L,
                 n_el  = length(obj))
          } else {
            list(str = paste(as.integer(dims), collapse = " x "),
                 n_dim = length(dims),
                 n_el  = as.integer(prod(dims)))
          }
          rows[[i]] <- summarise_object(
            x                  = obj,
            file_name          = file_name,
            var_name           = var,
            dims_info          = dims_info,
            format_label       = "v4/v5",
            max_full_numeric   = max_full_numeric,
            max_sample_numeric = max_sample_numeric
          )
        }
        bind_rows(rows)
      }
    }, error = function(e) {
      tibble(
        FileName      = file_name,
        VariableName  = "ERROR",
        Format        = "Unknown",
        Class         = "Error",
        Dimensions    = "-",
        NumDimensions = NA_integer_,
        NumElements   = NA_integer_,
        SummaryType   = paste("Failed to read:", conditionMessage(e)),
        Min           = NA_real_,
        Max           = NA_real_,
        Mean          = NA_real_,
        SD            = NA_real_,
        PropTrue      = NA_real_,
        NUnique       = NA_integer_,
        ExampleValues = NA_character_
      )
    })
  }
  
  content_summary_list[[idx]] <- res
  idx <- idx + 1L
}

mat_content_report <- bind_rows(content_summary_list)

content_csv <- file.path(output_dir,
                         paste0("Matlab_Content_Summary_", Sys.Date(), ".csv"))
write.csv(mat_content_report, content_csv, row.names = FALSE)
cat("\nContent summary written to :", content_csv, "\n")

cat("\nAll done.\n")
