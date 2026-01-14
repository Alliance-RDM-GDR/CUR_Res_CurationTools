#########ABOUT############

#>Script to open, check and extract metadata from fastq files
#>Started by Tamanna Moharana
#>Date started: January 8th, 2026

# Intent: This script is designed to locate files with .fastq and .fq extensions within the working directory, and then read and 
#>extract metadata into a csv files.
#>In terms of output, it will generate fastq_metadata.csv, fastq_metadata.err error file, and fastq_metadata.out output file 
#>summarizing the number of fastq files found, processed, and failed.

# Further work to be done:
#> Add code to extract the compressed files - currently can done on terminal using bash command

#####Packages to install in Cluster before proceeding with running the script###########
#>For running the code to check fastq files, you will need the ShortRead package specifically.
#>To install ShortRead, you should first ensure you have the correct version of R installed (r/4.5.0 - current for now), 
#>and then use the BiocManager package to install it from the Bioconductor repository. 

#>install BiocManager package in the R interactive session in the cluster: install.packages('BiocManager'). 
#>Then install the ShortRead package: BiocManager::install("ShortRead")

###########################

# Load required packages
library(ShortRead)   # For FASTQ handling
library(data.table)  # For efficient data storage

# Define input directory (adjust as needed)
input_dir <- "/path/to/working/directory"

# List all FASTQ files (including .fq and compressed .gz)
fastq_files <- list.files(input_dir, pattern = "\\.(fastq|fq)(\\.gz)?$", full.names = TRUE, recursive = TRUE)

# Check if files exist
cat("Found", length(fastq_files), "FASTQ files\n")
if (length(fastq_files) == 0) {
  stop("No FASTQ files found. Check your input directory and file extensions.")
}

# Function to extract metadata from a single FASTQ file with error handling
extract_metadata <- function(file) {
  tryCatch({
    fq <- readFastq(file)
    
    # Basic metadata
    num_reads <- length(fq)
    read_lengths <- width(sread(fq))
    avg_length <- mean(read_lengths)
    
    # Optional: GC content
    gc_content <- sum(letterFrequency(sread(fq), letters = c("G", "C"))) / sum(read_lengths)
    
    # Return as a data frame
    data.frame(
      file_name = basename(file),
      num_reads = num_reads,
      avg_length = avg_length,
      gc_content = round(gc_content, 4),
      status = "OK"
    )
  }, error = function(e) {
    message("Failed to process file: ", file, " | Error: ", e$message)
    data.frame(
      file_name = basename(file),
      num_reads = NA,
      avg_length = NA,
      gc_content = NA,
      status = paste("ERROR:", e$message)
    )
  })
}

# Process files sequentially
metadata_list <- lapply(fastq_files, extract_metadata)

# Combine results
metadata_df <- rbindlist(metadata_list)

# Save metadata to CSV
output_file <- "fastq_metadata.csv"
fwrite(metadata_df, output_file)

# Summary report
success_count <- sum(metadata_df$status == "OK")
error_count <- sum(metadata_df$status != "OK")
cat("\nSummary:\n")
cat("Total files:", nrow(metadata_df), "\n")
cat("Successfully processed:", success_count, "\n")
cat("Failed:", error_count, "\n")
cat("Metadata saved to:", output_file, "\n")

