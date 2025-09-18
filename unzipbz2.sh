#!/bin/sh
#SBATCH --account=
#SBATCH --mem-per-cpu=
#SBATCH --cpus-per-task=
#SBATCH --time=00:00:00

find -name "*bz2" -print -exec bzip2 -dk {} \;