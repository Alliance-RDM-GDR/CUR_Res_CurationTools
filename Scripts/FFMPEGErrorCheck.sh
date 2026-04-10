#!/bin/sh
#SBATCH --account=
#SBATCH --mem-per-cpu=
#SBATCH --cpus-per-task=
#SBATCH --time=

find -name "*.mp4" -exec sh -c "echo '{}' >> errors.log; ffmpeg -v error -i '{}' -map 0:1? -f null - 2>> errors.log" \;

# Remove the ? after -map 0:1 if the video file has audio.