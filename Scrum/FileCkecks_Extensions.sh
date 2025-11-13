#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:05:00 # 5 minutes
#SBATCH --job-name=ext_check

# Load the R module
module load R

# Define the directory you want to analyze
DATA_DIR="/scratch/your_user/your_project/data_v3"

# Run the R script, passing the data directory as an argument
Rscript FileChecks_Extensions_Script.R $DATA_DIR