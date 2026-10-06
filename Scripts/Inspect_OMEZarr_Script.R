#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_OMEZarr_Script.R
# Purpose: Structural and metadata inspection of OME-Zarr / Zarr (v2) image
#          stores (lightsheet, microscopy, bioimaging), whether they sit on disk
#          as plain "<name>.zarr" folders or are packed inside uncompressed .tar
#          files (a common way to hand thousands of small chunk files to a
#          repository). Nothing is decompressed: it reads the file listing and
#          the small JSON metadata files only, so it stays practical on tars of
#          tens of GB (one tar listing pass plus one metadata extraction pass;
#          the chunk payloads are skipped by seeking, never read).
#
# What it reports, one row per store x resolution level:
#   * Store layout: store path, top-level folder name inside the tar vs the tar's
#     own name, resolution levels present, entry count, chunk-file count and
#     bytes, empty (0-byte) chunk files.
#   * Chunk completeness: from .zarray (shape, chunks) the expected chunk grid is
#     rebuilt and compared with the chunk files actually present (missing and
#     unexpected chunks). Handles both "." and "/" chunk-key separators.
#   * Array description: shape, chunk shape, dtype, compressor, fill value.
#   * OME-NGFF metadata (.zattrs): axes and units, voxel scale, channel labels,
#     orientation, version, and whether the level listed in the metadata is the
#     level actually present.
#   * BIDS-Microscopy sidecar (*_SPIM.json / *.json next to the store) when
#     present: PixelSize, instrument, and the acquisition source-file names in
#     any TileConfiguration field. The sample codes in those source-file names
#     are compared with the subject ID, because an acquisition file that carries
#     a different animal/participant code than the container it was packed into
#     is exactly the kind of mislabel a file-name check cannot see.
#   * Leftover template text: BIDS dataset_description.json / README.md still
#     holding SPIMprep/BIDS boilerplate ("Name of the dataset", "Author Name 1",
#     "TODO"), and samples.tsv participant_id vs the subject ID.
#   * Container hygiene: whether the tar headers carry a named user/group account
#     (recorded as a flag and a count, NOT the account name, following the
#     project rule of not writing potentially identifying strings into outputs).
#
# Not done (by design): decoding chunk payloads (blosc/lz4/zstd) to check pixel
#   values; that needs the zarr/numcodecs libraries and reads the bulk of the
#   data, so the script confirms structure and metadata only, and says so.
#
# Tar tool: uses the `tar` found on PATH (GNU tar or Windows bsdtar); set TAR_PATH
#   to override. GNU tar needs --force-local for paths like D:/..., handled here.
#
# Validated against dataset 1828 (24 SPIMprep tars, 3 to 19 GB each): the
# LD18 cFos tar's listing, .zarray and .zattrs were first read by hand and the
# script's values for that tar were compared with them before trusting the rest.
#
# Usage:   Rscript Inspect_OMEZarr_Script.R <target_directory> [output_dir]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Directory with OME-Zarr stores or tars")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_OMEZarr")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_OMEZarr_Script.R /path/to/dataset [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_OMEZarr")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
target_dir <- normalizePath(target_dir, winslash = "/", mustWork = TRUE)
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(target_dir))

message(paste("Starting OME-Zarr analysis on:", target_dir))

# 2. Tar tool ------------------------------------------------------------------
tar_bin <- Sys.getenv("TAR_PATH", unset = "")
if (tar_bin == "") tar_bin <- Sys.which("tar")[[1]]
have_tar <- nzchar(tar_bin)
is_gnu_tar <- FALSE
if (have_tar) {
  ver <- tryCatch(system2(tar_bin, "--version", stdout = TRUE, stderr = TRUE), error = function(e) "")
  is_gnu_tar <- any(grepl("GNU tar", ver))
}
tar_args <- function(...) c(if (is_gnu_tar) "--force-local", ...)

# 3. Inventory -----------------------------------------------------------------
tar_files <- list.files(target_dir, pattern = "\\.tar$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
tar_files <- tar_files[!grepl("Curation_Results", tar_files, ignore.case = TRUE)]
zarr_dirs <- list.dirs(target_dir, recursive = TRUE, full.names = TRUE)
zarr_dirs <- zarr_dirs[grepl("\\.zarr$", zarr_dirs, ignore.case = TRUE) & !grepl("Curation_Results", zarr_dirs, ignore.case = TRUE)]

message(sprintf("Found %d tar file(s) and %d on-disk .zarr folder(s).", length(tar_files), length(zarr_dirs)))
if (length(tar_files) == 0 && length(zarr_dirs) == 0) {
  message("No .tar files or .zarr folders found. Exiting.")
  quit(status = 0)
}
if (length(tar_files) > 0 && !have_tar) stop("No `tar` executable found on PATH; set TAR_PATH.", call. = FALSE)

# 4. Helpers -------------------------------------------------------------------
# Parse one line of `tar -tv` output (GNU or bsdtar) into path/size/owner.
parse_tar_line <- function(x) {
  gnu <- str_match(x, "^(\\S{10})\\s+(\\S+)\\s+(\\d+)\\s+\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2}(?::\\d{2})?\\s+(.*)$")
  bsd <- str_match(x, "^(\\S{10})\\s+\\d+\\s+(\\S+)\\s+(\\S+)\\s+(\\d+)\\s+\\w{3}\\s+\\d{1,2}\\s+(?:\\d{2}:\\d{2}|\\d{4})\\s+(.*)$")
  tibble(
    is_dir = substr(x, 1, 1) == "d",
    owner = ifelse(!is.na(gnu[, 3]), gnu[, 3], paste(bsd[, 3], bsd[, 4], sep = "/")),
    size = as.numeric(ifelse(!is.na(gnu[, 4]), gnu[, 4], bsd[, 5])),
    path = ifelse(!is.na(gnu[, 5]), gnu[, 5], bsd[, 6])
  )
}

list_tar <- function(fp) {
  out <- system2(tar_bin, c(tar_args("-tvf", shQuote(fp))), stdout = TRUE, stderr = FALSE)
  parse_tar_line(out) %>% filter(!is.na(path))
}

extract_meta <- function(fp, dest) {
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  pats <- c("*.json", "*.tsv", "*.md", "*.zattrs", "*.zgroup", "*.zarray")
  system2(tar_bin, c(tar_args("-xf", shQuote(fp), "-C", shQuote(dest), if (is_gnu_tar) "--wildcards", shQuote(pats))),
          stdout = FALSE, stderr = FALSE)
}

list_disk_zarr <- function(root) {
  fl <- list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE, include.dirs = FALSE)
  fi <- file.info(fl)
  parent <- dirname(root)
  tibble(is_dir = FALSE, owner = NA_character_, size = fi$size,
         path = sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", parent), "/"), "", fl))
}

read_json_safe <- function(p) {
  if (!file.exists(p)) return(NULL)
  tryCatch(fromJSON(p, simplifyVector = FALSE), error = function(e) NULL)
}

read_text_safe <- function(p) {
  if (!file.exists(p)) return(character(0))
  tryCatch(readLines(p, warn = FALSE, encoding = "UTF-8"), error = function(e) character(0))
}

# Expected chunk keys from shape/chunks; keys can be "0.12.0.0" or "0/12/0/0".
expected_chunk_keys <- function(shape, chunks, sep) {
  ranges <- map2(shape, chunks, ~ seq_len(ceiling(.x / .y)) - 1L)
  grid <- do.call(expand.grid, c(ranges, KEEP.OUT.ATTRS = FALSE))
  do.call(paste, c(as.list(grid), sep = sep))
}

placeholder_hits <- function(desc, readme_lines) {
  hits <- character(0)
  if (!is.null(desc)) {
    if (identical(desc$Name, "Name of the dataset")) hits <- c(hits, "Name")
    if (!is.null(desc$License) && grepl("^The license for the dataset$", paste(desc$License, collapse = ""))) hits <- c(hits, "License")
    au <- unlist(desc$Authors)
    if (length(au) > 0 && any(grepl("^Author Name [0-9]+$", au))) hits <- c(hits, "Authors")
  }
  if (any(grepl("^\\s*-\\s*\\[ \\]|TODO", readme_lines))) hits <- c(hits, "README_TODO")
  paste(hits, collapse = "; ")
}

# 5. Per-store inspection ------------------------------------------------------
# `listing` has one row per archive entry (path relative to the tar root, or to
# the parent of the .zarr folder on disk); `meta_root` is where metadata files can
# be read (extracted tar dir, or the dataset dir for on-disk stores).
inspect_container <- function(container_label, container_path, listing, meta_root, is_tar) {
  tar_base <- sub("\\.tar$", "", basename(container_path), ignore.case = TRUE)
  files <- listing %>% filter(!is_dir)
  stores <- unique(sub("(\\.zarr)/.*$", "\\1", files$path[grepl("\\.zarr/", files$path, ignore.case = TRUE)]))
  top_folder <- unique(sub("/.*$", "", listing$path))
  n_owner <- if (is_tar) n_distinct(na.omit(listing$owner)) else NA_integer_
  named_owner <- if (is_tar) any(!is.na(listing$owner) & !grepl("^(root|0|nobody)(/|$)", listing$owner)) else NA

  if (length(stores) == 0) {
    return(tibble(Container = container_label, Store = NA_character_, Level = NA_character_,
                  Status = "No .zarr store found in container"))
  }

  subject_dir <- str_extract(container_path, "LD[A-Za-z]*\\d+|sub-[A-Za-z0-9]+")
  map_dfr(stores, function(st) {
    st_files <- files %>% filter(startsWith(path, paste0(st, "/")))
    rel <- substring(st_files$path, nchar(st) + 2)
    levels <- sort(unique(sub("/.*$", "", rel[grepl("/", rel)])))
    levels <- levels[grepl("^[0-9]+$", levels)]

    zattrs <- read_json_safe(file.path(meta_root, st, ".zattrs"))
    ms <- if (!is.null(zattrs$multiscales)) zattrs$multiscales[[1]] else NULL
    axes <- if (!is.null(ms$axes)) map_chr(ms$axes, ~ .x$name) else character(0)
    units <- if (!is.null(ms$axes)) map_chr(ms$axes, ~ if (is.null(.x$unit)) "-" else .x$unit) else character(0)
    ds_paths <- if (!is.null(ms$datasets)) map_chr(ms$datasets, ~ .x$path) else character(0)
    ch <- zattrs$omero$channels
    ch_labels <- if (!is.null(ch)) map_chr(ch, ~ if (is.null(.x$label)) NA_character_ else .x$label) else character(0)

    # Sidecar next to the store: <store base>.json  (BIDS-Microscopy _SPIM.json)
    sidecar_path <- file.path(meta_root, sub("\\.ome\\.zarr$|\\.zarr$", ".json", st, ignore.case = TRUE))
    side <- read_json_safe(sidecar_path)
    tile_cfg <- if (!is.null(side$ExtraMetadata$TileConfiguration$TileConfiguration)) side$ExtraMetadata$TileConfiguration$TileConfiguration else ""
    # TileConfiguration is "<n>  <file>;;(x, y)  <file>;;(x, y) ...". File names can
    # contain spaces ("[00 x 01]"), so split on the ";;(x, y)" coordinate markers.
    tile_names <- trimws(str_split(tile_cfg, ";;\\([^)]*\\)")[[1]])
    tile_names <- trimws(sub("^\\d+\\s+", "", tile_names))
    tile_names <- tile_names[nzchar(tile_names)]
    # Only names that begin with a time-of-day prefix (hh-mm-ss_) carry a sample code;
    # bare names such as "Z0000.ome.tif" (one file per z-slice) do not.
    coded <- tile_names[grepl("^\\d{2}-\\d{2}-\\d{2}_", tile_names)]
    tile_stem <- sub("^\\d{2}-\\d{2}-\\d{2}_", "", unique(coded))
    # Everything before "_Blaze" (or the first "[") is the sample/stain descriptor,
    # e.g. "LDH16_cfos_left". A sample code is not always one token ("LD_H18_cfos_left"),
    # so the ID check compares on the digits found in the descriptor.
    tile_desc <- unique(sub("_?Blaze.*$|\\[.*$", "", tile_stem))
    tile_code <- unique(unlist(str_extract_all(tile_desc, "\\d+")))
    tile_style <- if (length(tile_names) == 0) NA_character_ else if (length(coded) == 0) "generic (no sample code in names)" else if (length(coded) == length(tile_names)) "sample-coded" else "mixed"
    subj_id <- str_extract(st, "sub-[A-Za-z0-9]+")
    subj_num <- str_extract(ifelse(is.na(subj_id), container_path, subj_id), "\\d+")
    id_mismatch <- if (length(tile_code) == 0 || is.na(subj_num)) NA else !(as.integer(subj_num) %in% as.integer(tile_code))
    pix <- if (!is.null(side$PixelSize)) paste(unlist(side$PixelSize), collapse = " x ") else NA_character_

    # Dataset-level template files at the tar root
    root_prefix <- if (is_tar) top_folder[1] else NULL
    desc <- read_json_safe(if (is_tar) file.path(meta_root, root_prefix, "dataset_description.json") else file.path(dirname(meta_root), "none"))
    rd <- if (is_tar) read_text_safe(file.path(meta_root, root_prefix, "README.md")) else character(0)
    placeholders <- if (is_tar) placeholder_hits(desc, rd) else NA_character_
    samples <- if (is_tar) {
      p <- file.path(meta_root, root_prefix, "samples.tsv")
      if (file.exists(p)) tryCatch(read_tsv(p, show_col_types = FALSE), error = function(e) NULL) else NULL
    } else NULL
    samples_ok <- if (!is.null(samples) && "participant_id" %in% names(samples) && !is.na(subj_id)) all(samples$participant_id == subj_id) else NA

    map_dfr(if (length(levels) == 0) NA_character_ else levels, function(lv) {
      lv_files <- if (is.na(lv)) st_files[0, ] else st_files %>% filter(startsWith(path, paste0(st, "/", lv, "/")))
      za <- if (is.na(lv)) NULL else read_json_safe(file.path(meta_root, st, lv, ".zarray"))
      chunk_files <- lv_files %>% mutate(key = substring(path, nchar(st) + nchar(lv) + 3)) %>%
        filter(!grepl("(^|/)\\.z(array|attrs|group)$", key))
      sep <- if (nrow(chunk_files) > 0 && any(grepl("/", chunk_files$key))) "/" else "."
      exp_keys <- if (!is.null(za)) expected_chunk_keys(unlist(za$shape), unlist(za$chunks), sep) else character(0)
      missing_n <- if (!is.null(za)) length(setdiff(exp_keys, chunk_files$key)) else NA_integer_
      extra_n <- if (!is.null(za)) length(setdiff(chunk_files$key, exp_keys)) else NA_integer_
      tibble(
        Container = container_label,
        Store = st,
        Top_Level_Folder = paste(top_folder, collapse = "; "),
        Top_Level_Matches_Container_Name = if (is_tar) identical(top_folder, tar_base) else NA,
        Level = lv,
        Levels_Present = paste(levels, collapse = ","),
        Levels_In_Metadata = paste(ds_paths, collapse = ","),
        Metadata_Level_Present = if (length(ds_paths) > 0) all(ds_paths %in% levels) else NA,
        Entry_Count = nrow(listing),
        Chunk_Files = nrow(chunk_files),
        Chunk_GB = round(sum(chunk_files$size, na.rm = TRUE) / 1024^3, 3),
        Empty_Chunk_Files = sum(chunk_files$size == 0, na.rm = TRUE),
        Shape = if (!is.null(za)) paste(unlist(za$shape), collapse = " x ") else NA_character_,
        Chunk_Shape = if (!is.null(za)) paste(unlist(za$chunks), collapse = " x ") else NA_character_,
        Dtype = if (!is.null(za)) za$dtype else NA_character_,
        Compressor = if (!is.null(za) && !is.null(za$compressor)) paste0(za$compressor$id, "/", za$compressor$cname) else NA_character_,
        Zarr_Format = if (!is.null(za)) za$zarr_format else NA_integer_,
        Expected_Chunks = length(exp_keys),
        Missing_Chunks = missing_n,
        Unexpected_Chunks = extra_n,
        Axes = paste(axes, collapse = ","),
        Axis_Units = paste(units, collapse = ","),
        Voxel_Scale = if (!is.null(ms$datasets[[1]]$coordinateTransformations[[1]]$scale)) paste(unlist(ms$datasets[[1]]$coordinateTransformations[[1]]$scale), collapse = " x ") else NA_character_,
        Channel_Labels = paste(ch_labels, collapse = ","),
        NGFF_Version = if (!is.null(ms$version)) ms$version else NA_character_,
        Orientation = if (!is.null(zattrs$orientation)) zattrs$orientation else NA_character_,
        Sidecar_Found = !is.null(side),
        Sidecar_PixelSize = pix,
        Sidecar_Instrument = if (!is.null(side$InstrumentModel)) side$InstrumentModel else NA_character_,
        Sidecar_Tile_Files = length(tile_names),
        Sidecar_Tile_Name_Style = tile_style,
        Sidecar_Tile_Source_Codes = paste(tile_code, collapse = "; "),
        Sidecar_Tile_Source_Descriptor = paste(tile_desc, collapse = "; "),
        Subject_ID = subj_id,
        Tile_Code_vs_Subject_Mismatch = id_mismatch,
        Samples_Tsv_Matches_Subject = samples_ok,
        Template_Placeholders = placeholders,
        Tar_Distinct_Owner_Accounts = n_owner,
        Tar_Has_Named_Owner_Account = named_owner,
        Status = "Success"
      )
    })
  })
}

# 6. Execution -----------------------------------------------------------------
results <- list()
tmp_root <- file.path(tempdir(), "omezarr_meta")

for (i in seq_along(tar_files)) {
  fp <- tar_files[i]
  message(sprintf("[%d/%d] %s (%.1f GB)", i, length(tar_files), basename(fp), file.size(fp) / 1024^3))
  res <- tryCatch({
    listing <- list_tar(fp)
    if (!any(grepl("\\.zarr(/|$)", listing$path, ignore.case = TRUE))) {
      tibble(Container = basename(fp), Store = NA_character_, Level = NA_character_,
             Status = "Tar does not contain a .zarr store")
    } else {
      dest <- file.path(tmp_root, sprintf("t%03d", i))
      extract_meta(fp, dest)
      inspect_container(basename(fp), fp, listing, dest, is_tar = TRUE)
    }
  }, error = function(e) {
    tibble(Container = basename(fp), Store = NA_character_, Level = NA_character_, Status = paste("Failed:", conditionMessage(e)))
  })
  results[[length(results) + 1]] <- res
}

for (zd in zarr_dirs) {
  message(sprintf("On-disk store: %s", zd))
  res <- tryCatch({
    listing <- list_disk_zarr(zd)
    inspect_container(basename(zd), zd, listing, dirname(zd), is_tar = FALSE)
  }, error = function(e) {
    tibble(Container = basename(zd), Store = NA_character_, Level = NA_character_, Status = paste("Failed:", conditionMessage(e)))
  })
  results[[length(results) + 1]] <- res
}

report <- bind_rows(results)
unlink(tmp_root, recursive = TRUE)

output_file <- file.path(output_dir, paste0("OMEZarr_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

# 7. Codebook ------------------------------------------------------------------
desc_map <- c(
  Container = "Tar file name (or .zarr folder name) inspected.",
  Store = "Path of the .zarr store inside the container.",
  Top_Level_Folder = "Top-level folder name(s) inside the tar.",
  Top_Level_Matches_Container_Name = "TRUE if the single top-level folder equals the tar name without .tar (what a README usually promises: 'extracts to <name>/').",
  Level = "Resolution level (numeric folder inside the store) this row describes.",
  Levels_Present = "All numeric resolution-level folders found in the store.",
  Levels_In_Metadata = "Dataset paths listed in .zattrs multiscales.",
  Metadata_Level_Present = "TRUE if every level named in the metadata exists in the store.",
  Entry_Count = "Number of entries (files and folders) in the container.",
  Chunk_Files = "Number of chunk files at this level (everything except .zarray/.zattrs/.zgroup).",
  Chunk_GB = "Total size of the chunk files at this level, in GiB (as stored, compressed).",
  Empty_Chunk_Files = "Chunk files of 0 bytes (would fail to decode).",
  Shape = "Array shape from .zarray.",
  Chunk_Shape = "Chunk shape from .zarray.",
  Dtype = "Numpy-style data type from .zarray (e.g. <u2 = little-endian uint16).",
  Compressor = "Compressor id/codec from .zarray.",
  Zarr_Format = "zarr_format from .zarray (2 or 3).",
  Expected_Chunks = "Chunks the shape/chunk grid implies.",
  Missing_Chunks = "Expected chunk keys with no file present (nonzero = incomplete store; all-zero background chunks are sometimes legitimately omitted by writers, check the fill_value before treating as an error).",
  Unexpected_Chunks = "Chunk files present that the shape/chunk grid does not account for.",
  Axes = "Axis names from the OME-NGFF multiscales metadata.",
  Axis_Units = "Axis units from the metadata ('-' = none declared, e.g. channel axis).",
  Voxel_Scale = "Scale coordinate transformation of the first dataset (per axis, in Axis_Units).",
  Channel_Labels = "Channel labels from the omero metadata.",
  NGFF_Version = "OME-NGFF version from the multiscales metadata.",
  Orientation = "Non-standard 'orientation' string from .zattrs, if present.",
  Sidecar_Found = "TRUE if a BIDS-Microscopy .json sidecar sits next to the store.",
  Sidecar_PixelSize = "PixelSize from the sidecar (acquisition resolution, may differ from the level stored).",
  Sidecar_Instrument = "InstrumentModel from the sidecar.",
  Sidecar_Tile_Files = "Number of acquisition tile file names found in TileConfiguration.",
  Sidecar_Tile_Name_Style = "sample-coded (names start with a time-of-day prefix and a sample code), generic (bare names such as Z0000.ome.tif, one per z-slice, no sample code to check), or mixed.",
  Sidecar_Tile_Source_Codes = "Number(s) found in the sample descriptor of the acquisition tile file names.",
  Sidecar_Tile_Source_Descriptor = "Sample descriptor(s) from the tile file names without the time-of-day prefix (e.g. sample code, stain, side).",
  Subject_ID = "Subject ID parsed from the store path (sub-...).",
  Tile_Code_vs_Subject_Mismatch = "TRUE if the numeric part of the tile source code differs from the subject number: the acquisition files may belong to a different subject than the container name says. Confirm with the depositor.",
  Samples_Tsv_Matches_Subject = "TRUE if samples.tsv participant_id equals the store's subject ID.",
  Template_Placeholders = "Leftover boilerplate in dataset_description.json / README.md (Name, License, Authors, README_TODO).",
  Tar_Distinct_Owner_Accounts = "Number of distinct owner/group strings in the tar headers (values not recorded).",
  Tar_Has_Named_Owner_Account = "TRUE if the tar headers carry a user account name other than root/0 (value not recorded; consider whether it identifies a person).",
  Status = "Success, or the reason the container could not be read."
)
codebook <- tibble(
  Variable = names(report),
  Type = map_chr(report, function(col) {
    if (is.logical(col)) "Logical" else if (is.integer(col)) "Integer" else if (is.numeric(col)) "Numeric" else "Text"
  }),
  Description = unname(ifelse(names(report) %in% names(desc_map), desc_map[names(report)], ""))
)
write_excel_csv(codebook, file.path(output_dir, "OMEZarr_Report_Codebook.csv"))

# 8. Console summary -----------------------------------------------------------
ok <- report %>% filter(Status == "Success")
message(sprintf("Process complete. %d store-level row(s) from %d container(s); %d failed or without a store.",
                nrow(ok), n_distinct(ok$Container), nrow(report) - nrow(ok)))
if (nrow(ok) > 0) {
  message("  NOTE: structure and metadata only; chunk payloads were not decoded (no pixel-value check).")
  if (any(ok$Missing_Chunks > 0, na.rm = TRUE)) message(sprintf("  WARNING: %d row(s) have missing chunks.", sum(ok$Missing_Chunks > 0, na.rm = TRUE)))
  if (any(ok$Unexpected_Chunks > 0, na.rm = TRUE)) message(sprintf("  WARNING: %d row(s) have unexpected chunk files.", sum(ok$Unexpected_Chunks > 0, na.rm = TRUE)))
  if (any(ok$Empty_Chunk_Files > 0, na.rm = TRUE)) message(sprintf("  WARNING: %d row(s) have 0-byte chunk files.", sum(ok$Empty_Chunk_Files > 0, na.rm = TRUE)))
  if (any(ok$Top_Level_Matches_Container_Name == FALSE, na.rm = TRUE)) message("  WARNING: top-level folder name does not match the tar name for some containers.")
  if (any(ok$Tile_Code_vs_Subject_Mismatch, na.rm = TRUE)) message(sprintf("  WARNING: %d container(s) have acquisition tile source codes that do not match the subject ID.", sum(ok$Tile_Code_vs_Subject_Mismatch, na.rm = TRUE)))
  if (any(nzchar(ok$Template_Placeholders), na.rm = TRUE)) message(sprintf("  NOTE: %d container(s) still hold template placeholder text.", sum(nzchar(ok$Template_Placeholders), na.rm = TRUE)))
  if (any(ok$Tar_Has_Named_Owner_Account, na.rm = TRUE)) message("  NOTE: tar headers carry a named user account; check whether it identifies a person.")
}
message(paste("Report saved to:", output_file))
