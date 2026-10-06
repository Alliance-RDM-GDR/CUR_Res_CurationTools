#!/usr/bin/env Rscript

# ==============================================================================
# Script: Inspect_Video_Script.R
# Purpose: Batch inspection of video files (.mp4, .mov, .mkv, .avi, .wmv) for
#          archival quality: container/codec metadata, duration, resolution,
#          presence of an audio track, and a stream-integrity check (decode
#          errors) via ffmpeg/ffprobe.
# Requires: ffmpeg and ffprobe available on PATH (or set FFMPEG_PATH /
#           FFPROBE_PATH environment variables to their full paths).
# Usage:   Rscript Inspect_Video_Script.R <target_directory>
# ==============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
})

# 1. Setup & Arguments (Hybrid: Interactive / HPC) ------------------------------
if (interactive()) {
  message("Running in interactive mode. Please select a directory.")
  if (requireNamespace("rstudioapi", quietly = TRUE)) {
    target_dir <- rstudioapi::selectDirectory(caption = "Select Video Directory")
  } else {
    stop("Package 'rstudioapi' is required for interactive selection.")
  }
  if (is.null(target_dir)) stop("No directory selected.")
  output_dir <- file.path(getwd(), "Results/Inspect_Video")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) == 0) {
    stop("Error: No target directory provided.\nUsage: Rscript Inspect_Video_Script.R /path/to/video_files [output_dir]", call. = FALSE)
  }
  target_dir <- args[1]
  if (!dir.exists(target_dir)) {
    stop(paste("Error: Directory not found:", target_dir), call. = FALSE)
  }
  output_dir <- if (length(args) >= 2) args[2] else file.path(getwd(), "Results/Inspect_Video")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

dir_label <- gsub("[^A-Za-z0-9_.-]", "_", basename(sub("[/\\\\]+$", "", target_dir)))

# Locate ffprobe/ffmpeg: environment variable override, else assume on PATH.
ffprobe_bin <- Sys.getenv("FFPROBE_PATH", unset = "ffprobe")
ffmpeg_bin  <- Sys.getenv("FFMPEG_PATH", unset = "ffmpeg")

has_ffprobe <- nzchar(Sys.which(ffprobe_bin))
has_ffmpeg  <- nzchar(Sys.which(ffmpeg_bin))

if (!has_ffprobe || !has_ffmpeg) {
  stop("ffmpeg and ffprobe are required but were not found on PATH. Set FFPROBE_PATH/FFMPEG_PATH or install ffmpeg.", call. = FALSE)
}

message(paste("Starting video analysis on:", target_dir))

# 2. Inventory -----------------------------------------------------------------
video_files <- list.files(
  path = target_dir,
  pattern = "\\.(mp4|mov|mkv|avi|wmv|m4v)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)
video_files <- video_files[!grepl("Curation_Results", video_files, ignore.case = TRUE)]

message(paste("Found", length(video_files), "video file(s)."))

if (length(video_files) == 0) {
  message("No video files found. Exiting.")
  quit(status = 0)
}

# 3. Processing Function -------------------------------------------------------
inspect_video <- function(fp) {
  fname <- basename(fp)
  file_size_mb <- round(file.size(fp) / 1024^2, 2)

  tryCatch({
    # A. Metadata via ffprobe (JSON output)
    # shQuote() is required here: system2() does not reliably quote a path
    # argument containing spaces on Windows, which silently splits it into
    # two arguments and makes ffprobe fail as if the file didn't exist.
    probe_args <- c("-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", shQuote(fp))
    probe_json <- suppressWarnings(system2(ffprobe_bin, probe_args, stdout = TRUE, stderr = FALSE))
    probe <- fromJSON(paste(probe_json, collapse = "\n"))
    # ffprobe prints nothing usable when it cannot parse the container (e.g. a
    # truncated file); without this check the row silently vanishes from the report.
    if (is.null(probe$format)) stop("ffprobe could not read the container (file may be truncated or corrupt)")

    duration_sec <- as.numeric(probe$format$duration)
    container <- probe$format$format_name

    streams <- probe$streams
    video_stream <- if (!is.null(streams) && "codec_type" %in% names(streams)) {
      streams[streams$codec_type == "video", , drop = FALSE]
    } else NULL
    audio_stream <- if (!is.null(streams) && "codec_type" %in% names(streams)) {
      streams[streams$codec_type == "audio", , drop = FALSE]
    } else NULL

    has_video <- !is.null(video_stream) && nrow(video_stream) > 0
    has_audio <- !is.null(audio_stream) && nrow(audio_stream) > 0

    video_codec <- if (has_video) video_stream$codec_name[1] else NA_character_
    width  <- if (has_video) as.integer(video_stream$width[1]) else NA_integer_
    height <- if (has_video) as.integer(video_stream$height[1]) else NA_integer_
    frame_rate_raw <- if (has_video) video_stream$r_frame_rate[1] else NA_character_
    frame_rate <- if (!is.na(frame_rate_raw)) {
      parts <- as.numeric(str_split_1(frame_rate_raw, "/"))
      round(parts[1] / parts[2], 2)
    } else NA_real_

    audio_codec <- if (has_audio) audio_stream$codec_name[1] else NA_character_

    # B. Stream-integrity check via ffmpeg (decode the whole file, report errors)
    map_arg <- if (has_audio) "0" else "0:v"
    integrity_args <- c("-v", "error", "-i", shQuote(fp), "-map", map_arg, "-f", "null", "-")
    integrity_log <- suppressWarnings(system2(ffmpeg_bin, integrity_args, stdout = FALSE, stderr = TRUE))
    has_errors <- length(integrity_log) > 0
    error_preview <- if (has_errors) paste(head(integrity_log, 3), collapse = " | ") else ""

    tibble(
      FileName = fname,
      Size_MB = file_size_mb,
      Container = container,
      Duration_sec = round(duration_sec, 1),
      Has_Video_Stream = has_video,
      Video_Codec = video_codec,
      Width = width,
      Height = height,
      Frame_Rate = frame_rate,
      Has_Audio_Stream = has_audio,
      Audio_Codec = audio_codec,
      Decode_Errors_Found = has_errors,
      Decode_Error_Preview = error_preview,
      Status = "Success"
    )

  }, error = function(e) {
    tibble(
      FileName = fname, Size_MB = file_size_mb, Container = NA, Duration_sec = NA,
      Has_Video_Stream = NA, Video_Codec = NA, Width = NA, Height = NA, Frame_Rate = NA,
      Has_Audio_Stream = NA, Audio_Codec = NA, Decode_Errors_Found = NA, Decode_Error_Preview = NA,
      Status = paste("Inspection Failed:", e$message)
    )
  })
}

# 4. Execution -----------------------------------------------------------------
message("Probing video files and checking stream integrity (this decodes each file — may take a while for large videos)...")
report <- map_dfr(video_files, inspect_video)

# 5. Export --------------------------------------------------------------------
output_file <- file.path(output_dir, paste0("Video_Report_", dir_label, "_", format(Sys.Date(), "%Y%m%d"), ".csv"))
write_excel_csv(report, output_file)

codebook <- tibble(
  Variable = c("FileName", "Size_MB", "Container", "Duration_sec", "Has_Video_Stream",
               "Video_Codec", "Width", "Height", "Frame_Rate", "Has_Audio_Stream",
               "Audio_Codec", "Decode_Errors_Found", "Decode_Error_Preview", "Status"),
  Type = c("Text", "Numeric", "Text", "Numeric", "Logical", "Text", "Integer", "Integer",
           "Numeric", "Logical", "Text", "Logical", "Text", "Text"),
  Description = c(
    "Name of the video file.",
    "File size in megabytes.",
    "Container/format name reported by ffprobe (e.g. mov,mp4,m4a,3gp,3g2,mj2).",
    "Duration in seconds.",
    "TRUE if a video stream was detected.",
    "Video codec (e.g. h264, hevc).",
    "Frame width in pixels.",
    "Frame height in pixels.",
    "Frames per second.",
    "TRUE if an audio stream was detected — a video with no audio track may be missing dialogue/narration that should have been captured, or may be intentionally silent.",
    "Audio codec (e.g. aac), NA if no audio stream.",
    "TRUE if ffmpeg reported decode errors while reading the full file (stream corruption/truncation risk).",
    "First few ffmpeg error lines, if any, to help diagnose the issue.",
    'Either "Success" or "Inspection Failed: <error message>".'
  )
)
codebook_file <- file.path(output_dir, "Video_Report_Codebook.csv")
write_excel_csv(codebook, codebook_file)

message(paste("Process complete. Report saved to:", output_file))
if (any(report$Decode_Errors_Found, na.rm = TRUE)) {
  message("WARNING: one or more video files reported decode errors — investigate before publication.")
}
