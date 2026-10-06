#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_C3D_Script.R
# Purpose: Batch inspection of C3D motion-capture files (biomechanics/robotic
#          assessment instruments such as KINARM). Reads the fixed-layout
#          header (point/analog counts, frame range, frame rate, data format)
#          and parses the parameter section to list every character-type
#          (string) parameter in the file, flagging ones that look like they
#          may hold free text or an identifying code rather than a numeric ID
#          or a known non-identifying value.
#
#          C3D files are usually shipped inside per-exam .zip archives, not as
#          standalone files, so this script also samples one representative
#          trial C3D from each archive found in the target directory (not
#          every trial in every archive, which could mean extracting tens of
#          thousands of files on a large dataset).
#
# Scope / limitations (read before trusting a "clean" result):
#   - Implements the documented C3D parameter-record binary layout for the
#     common case (Intel/little-endian processor type, byte 4 of the
#     parameter header == 84). Files written by a DEC or MIPS/SGI system
#     (processor type 85/86) are not decoded; they are reported with
#     Status = "Unsupported processor type".
#   - Only character-type parameters are decoded into readable values.
#     Numeric parameters (HEIGHT, WEIGHT, calibration constants, etc.) are
#     counted but not decoded, since they are not the PII-screening target.
#   - This is a header/parameter-section reader, not a full C3D validator: it
#     does not check the 3D point or analog data blocks for corruption.
#   - The PII heuristic (Likely_PII_Value) is pattern-based, not a verdict:
#     confirm every hit by reading the actual value, and do not assume a
#     file with no hits has no identifying text (this script narrows what a
#     human needs to check, it does not replace checking).
#
# Usage:   Rscript Inspect_C3D_Script.R <target_directory> [output_dir]
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(archive)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Directory Containing C3D Files / Exam Archives")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_C3D")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_C3D_Script.R /path/to/dataset [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_C3D")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# ------------------------------------------------------------------------------
# 2. C3D Parsing ----------------------------------------------------------------
# ------------------------------------------------------------------------------

# Reads the 512-byte header block. Returns a list of the fields useful for
# curation triage; see the C3D spec (c3d.org) for the full field layout.
read_c3d_header <- function(raw) {
  if (length(raw) < 512) stop("File shorter than one C3D block (512 bytes); not a valid C3D file.")
  if (as.integer(raw[2]) != 80L) stop("Byte 2 is not 0x50 (80); not a valid C3D file.")

  param_start_block <- as.integer(raw[1])
  read_i16 <- function(off) as.integer(readBin(raw[off:(off + 1)], "integer", n = 1, size = 2, signed = TRUE, endian = "little"))
  read_f32 <- function(off) readBin(raw[off:(off + 3)], "double", n = 1, size = 4, endian = "little")

  list(
    param_start_block = param_start_block,
    num_points        = read_i16(3),
    analog_per_frame   = read_i16(5),
    first_frame       = read_i16(7),
    last_frame        = read_i16(9),
    scale_factor      = read_f32(13),
    data_start_block  = read_i16(17),
    analog_samples_per_3d_frame = read_i16(19),
    frame_rate        = read_f32(21)
  )
}

# Walks the parameter section starting at byte offset `start` (1-indexed, into
# `raw`) and returns a tibble of every parameter record found: group name
# (resolved from the matching negative-groupId group-definition record when
# available), parameter name, data type, and decoded value for character data.
parse_c3d_parameters <- function(raw, start, end) {
  pos <- start
  groups <- list()   # abs(groupId) -> group name
  params <- list()

  # First pass: walk every record once, classifying as group or parameter.
  records <- list()
  guard <- 0
  while (pos < end && guard < 100000) {
    guard <- guard + 1
    name_len_signed <- as.integer(raw[pos])
    if (as.raw(raw[pos]) == as.raw(0x00)) break  # name length 0 marks end of parameter section
    name_len <- abs(name_len_signed)
    group_id <- as.integer(raw[pos + 1])
    if (group_id == 0 || pos + 2 + name_len > end) break

    name <- rawToChar(raw[(pos + 2):(pos + 1 + name_len)])
    name <- gsub("[^[:print:]]", "", name)
    next_off_pos <- pos + 2 + name_len
    next_offset <- as.integer(readBin(raw[next_off_pos:(next_off_pos + 1)], "integer", n = 1, size = 2, signed = TRUE, endian = "little"))
    record_start <- pos
    body_start <- next_off_pos + 2

    if (group_id < 0) {
      # Group definition: [descLength(1)][description]
      desc_len <- as.integer(raw[body_start])
      groups[[as.character(abs(group_id))]] <- name
    } else {
      # Parameter: [dataType(1)][numDims(1)][dims(numDims)][data][descLen(1)][desc]
      data_type <- as.integer(raw[body_start])
      if (data_type >= 128) data_type <- data_type - 256L  # signed byte
      num_dims <- as.integer(raw[body_start + 1])
      dims <- if (num_dims > 0) as.integer(raw[(body_start + 2):(body_start + 1 + num_dims)]) else integer(0)
      data_start <- body_start + 2 + num_dims
      type_size <- switch(as.character(data_type), "-1" = 1L, "1" = 1L, "2" = 2L, "4" = 4L, 1L)
      n_elements <- if (length(dims) > 0) prod(dims) else 1L
      data_len <- n_elements * type_size

      value <- NA_character_
      if (data_type == -1 && data_len > 0 && data_start + data_len - 1 <= end) {
        raw_chars <- raw[data_start:(data_start + data_len - 1)]
        if (num_dims <= 1) {
          value <- rawToChar(raw_chars[raw_chars != as.raw(0)])
        } else {
          # dims[1] = characters per string, dims[2] = number of strings (column-major)
          chars_per <- dims[1]
          n_strings <- if (length(dims) >= 2) dims[2] else 1L
          vals <- vapply(seq_len(n_strings), function(i) {
            s <- raw_chars[((i - 1) * chars_per + 1):(i * chars_per)]
            trimws(rawToChar(s[s != as.raw(0)]))
          }, character(1))
          value <- paste(vals, collapse = " | ")
        }
        value <- gsub("[^[:print:]]", "", value)
        value <- trimws(value)
      }

      records[[length(records) + 1]] <- list(
        group_id = group_id, name = name, data_type = data_type, value = value
      )
    }

    if (next_offset <= 0) break
    # Offset is measured from the byte immediately after the offset field
    # itself (i.e. from `next_off_pos`, the position of the offset's low
    # byte, plus the offset value), not from the start of this record.
    pos <- next_off_pos + next_offset
  }

  if (length(records) == 0) return(tibble(Group = character(0), Parameter = character(0), Value = character(0), Is_Char_Type = logical(0)))

  map_dfr(records, function(r) {
    tibble(
      Group = if (!is.null(groups[[as.character(r$group_id)]])) groups[[as.character(r$group_id)]] else paste0("group_", r$group_id),
      Parameter = r$name,
      Value = r$value,
      Is_Char_Type = r$data_type == -1
    )
  })
}

# Heuristic: does a character parameter's value look like free text or a
# short identifying code, as opposed to a numeric ID, a known enum keyword,
# or blank? This narrows what a human needs to read; it is not a verdict.
non_identifying_keywords <- c("na", "n/a", "unknown", "none", "seated", "standing",
                               "true", "false", "left", "right", "m", "f", "yes", "no")
looks_suspect <- function(value) {
  if (is.na(value) || value == "") return(FALSE)
  v <- trimws(value)
  if (grepl("^[0-9._-]+$", v)) return(FALSE)             # purely numeric (an ID, a version number)
  if (tolower(v) %in% non_identifying_keywords) return(FALSE)
  if (grepl("^[A-Za-z0-9_.-]{1,40}$", v) && nchar(v) <= 40) return(TRUE)  # short code/word: name, initials, protocol tag
  TRUE  # anything longer / with spaces / punctuation: free text (notes, operator name, etc.)
}

inspect_one_c3d <- function(raw, source_label) {
  tryCatch({
    hdr <- read_c3d_header(raw)

    # header byte 1 is the number of 512-byte blocks *before* the parameter
    # section (i.e. it is 0 if the parameter section immediately followed the
    # header, which it never does), not a 1-indexed block number: verified
    # empirically against KINARM-exported files, where byte 1 == 1 and the
    # valid parameter-section header (reserved, reserved, n_blocks, processor
    # type 84) is found at file block 2 (byte offset 513), i.e. at
    # header_byte1 * 512 + 1, not (header_byte1 - 1) * 512 + 1.
    param_block_start <- hdr$param_start_block * 512L + 1L
    if (param_block_start > length(raw) || param_block_start < 1) {
      stop("Parameter start block is out of range.")
    }
    n_param_blocks <- as.integer(raw[param_block_start + 2L])
    processor_type <- as.integer(raw[param_block_start + 3L])
    if (!processor_type %in% c(84L)) {
      return(tibble(
        Source = source_label, NumPoints = hdr$num_points, NumAnalogChannels = NA,
        FirstFrame = hdr$first_frame, LastFrame = hdr$last_frame,
        NumFrames = hdr$last_frame - hdr$first_frame + 1L, FrameRate = hdr$frame_rate,
        DataFormat = if (hdr$scale_factor < 0) "Floating-point" else "Integer",
        CharParameterCount = NA, Suspect_PII_Parameters = NA,
        Status = paste0("Unsupported processor type (", processor_type, "); header stats only")
      ))
    }

    param_end <- min(length(raw), param_block_start - 1L + n_param_blocks * 512L)
    params <- parse_c3d_parameters(raw, param_block_start + 4L, param_end)
    char_params <- params %>% filter(Is_Char_Type, !is.na(Value), Value != "")
    suspect <- char_params %>% filter(map_lgl(Value, looks_suspect))

    analog_channels <- if (hdr$analog_samples_per_3d_frame > 0 && (hdr$last_frame - hdr$first_frame + 1) > 0) {
      hdr$analog_per_frame
    } else NA_integer_

    tibble(
      Source = source_label,
      NumPoints = hdr$num_points,
      NumAnalogChannels = analog_channels,
      FirstFrame = hdr$first_frame,
      LastFrame = hdr$last_frame,
      NumFrames = hdr$last_frame - hdr$first_frame + 1L,
      FrameRate = round(hdr$frame_rate, 2),
      DataFormat = if (hdr$scale_factor < 0) "Floating-point" else "Integer",
      CharParameterCount = nrow(char_params),
      Suspect_PII_Parameters = if (nrow(suspect) > 0) {
        paste(sprintf("%s.%s=%s", suspect$Group, suspect$Parameter,
                       ifelse(nchar(suspect$Value) > 60, paste0(substr(suspect$Value, 1, 60), "..."), suspect$Value)),
              collapse = " ; ")
      } else "",
      Status = "Success"
    )
  }, error = function(e) {
    tibble(Source = source_label, NumPoints = NA, NumAnalogChannels = NA, FirstFrame = NA,
           LastFrame = NA, NumFrames = NA, FrameRate = NA, DataFormat = NA,
           CharParameterCount = NA, Suspect_PII_Parameters = NA,
           Status = paste("Read Failed:", e$message))
  })
}

# ------------------------------------------------------------------------------
# 3. Inventory: standalone .c3d files, plus one sampled trial per archive -------
# ------------------------------------------------------------------------------
standalone_c3d <- list.files(target_dir, pattern = "\\.c3d$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
standalone_c3d <- standalone_c3d[!grepl("Curation_Results", standalone_c3d, ignore.case = TRUE)]

archive_files <- list.files(target_dir, pattern = "\\.(zip|report)$", recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
archive_files <- archive_files[!grepl("Curation_Results", archive_files, ignore.case = TRUE)]

message(sprintf("Found %d standalone .c3d file(s) and %d archive(s) to sample.", length(standalone_c3d), length(archive_files)))

results <- list()

for (fp in standalone_c3d) {
  raw <- readBin(fp, "raw", n = file.info(fp)$size)
  results[[length(results) + 1]] <- inspect_one_c3d(raw, basename(fp))
}

if (length(archive_files) > 0) {
  message("Sampling one trial C3D from each archive (this reads inside the zip without extracting to disk)...")
  for (fp in archive_files) {
    label <- basename(fp)
    tryCatch({
      contents <- archive::archive(fp)
      candidates <- contents$path[grepl("\\.c3d$", contents$path, ignore.case = TRUE) & !grepl("common", contents$path, ignore.case = TRUE)]
      if (length(candidates) == 0) {
        candidates <- contents$path[grepl("\\.c3d$", contents$path, ignore.case = TRUE)]
      }
      if (length(candidates) == 0) {
        results[[length(results) + 1]] <- tibble(
          Source = paste0(label, " (no .c3d found)"), NumPoints = NA, NumAnalogChannels = NA,
          FirstFrame = NA, LastFrame = NA, NumFrames = NA, FrameRate = NA, DataFormat = NA,
          CharParameterCount = NA, Suspect_PII_Parameters = NA, Status = "No .c3d member in archive"
        )
        next
      }
      con <- archive::archive_read(fp, file = candidates[1], mode = "rb")
      raw <- readBin(con, "raw", n = 50 * 1024 * 1024)  # C3D header+params are small; cap well above any realistic trial size
      close(con)
      results[[length(results) + 1]] <- inspect_one_c3d(raw, paste0(label, " :: ", candidates[1]))
    }, error = function(e) {
      results[[length(results) + 1]] <<- tibble(
        Source = label, NumPoints = NA, NumAnalogChannels = NA, FirstFrame = NA, LastFrame = NA,
        NumFrames = NA, FrameRate = NA, DataFormat = NA, CharParameterCount = NA,
        Suspect_PII_Parameters = NA, Status = paste("Archive Read Failed:", e$message)
      )
    })
  }
}

if (length(results) == 0) {
  message("No .c3d files or archives found. Exiting.")
  quit(status = 0)
}

report <- bind_rows(results)

# ------------------------------------------------------------------------------
# 4. Export ----------------------------------------------------------------------
# ------------------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("C3D_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("Source", "NumPoints", "NumAnalogChannels", "FirstFrame", "LastFrame", "NumFrames",
               "FrameRate", "DataFormat", "CharParameterCount", "Suspect_PII_Parameters", "Status"),
  Type = c("Text", "Integer", "Integer", "Integer", "Integer", "Integer", "Numeric", "Text",
           "Integer", "Text", "Text"),
  Description = c(
    "File name (standalone) or 'archive :: internal/path.c3d' (sampled from inside a zip/report archive; one representative trial per archive, not every trial).",
    "Number of 3D marker points per frame, from the C3D header.",
    "Analog samples per 3D frame, from the header (NA if not applicable to this file).",
    "First frame number.", "Last frame number.", "Last minus first frame, plus one.",
    "Capture frame rate (Hz).",
    "\"Floating-point\" or \"Integer\", from the sign of the header scale factor.",
    "Count of character-type (string) parameters found in the parameter section.",
    "Character parameters whose value did not match a purely-numeric or known-keyword pattern, as \"Group.Parameter=value\" pairs, semicolon-separated. A heuristic filter for a human to read, not a PII verdict; a blank result is not proof of no PII.",
    'Either "Success", "Unsupported processor type (...)" (DEC/MIPS files: header stats only, parameters not decoded), "No .c3d member in archive", or a "...Failed: <error>" message.'
  )
)
codebook_file <- file.path(output_dir, "C3D_Report_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(paste("Process complete. Report saved to:", output_file))
if (any(nzchar(coalesce(report$Suspect_PII_Parameters, "")), na.rm = TRUE)) {
  message("NOTICE: one or more files have character parameters flagged for human review (Suspect_PII_Parameters).")
}
