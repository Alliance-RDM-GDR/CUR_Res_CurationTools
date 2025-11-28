#!/bin/sh
#SBATCH --account=
#SBATCH --mem-per-cpu=
#SBATCH --cpus-per-task=
#SBATCH --ntasks=
#SBATCH --time=

#This script creates a .csv that identifies empty directories and files smaller than 10KB. Place it in the top level directory and then run.

echo "Empty Directories" > output.csv

find . -depth -type d -empty -printf '%p\n' >> output.csv

echo "Files under 10KB" >> output.csv

find . -type f -size -10k -printf '%kKB,%p\n' >> output.csv

exit