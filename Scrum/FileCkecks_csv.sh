#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00 # 10 minutes
#SBATCH --job-name=csv_check

# Load the R module
module load R

# Define the directory you want to analyze
DATA_DIR="/scratch/your_user/your_project/data_v3"

# Run the R script, passing the data directory as an argument
Rscript check_csvs.R $DATA_DIR