#!/bin/sh
#SBATCH --account=
#SBATCH --mem-per-cpu=
#SBATCH --cpus-per-task=
#SBATCH --ntasks=
#SBATCH --time=

#This script creates two .csvs that identifies empty directories and files smaller than 10KB. Place it in the top level directory and then run.

echo "Empty Directories" > directoriesOutput.csv

find . -depth -type d -empty -printf '%p\n' >> directoriesOutput.csv

echo "Files under 10KB" >> filesOutput.csv

find . -type f -size -10k -printf '%kKB,%p\n' >> filesOutput.csv

exit
