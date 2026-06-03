#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash submit_workshop_module.sh <module> <input_dir> <output_root> [scripts_dir] [time] [mem] [cpus]

Defaults:
  time = 00:30:00
  mem  = 4G
  cpus = 1

Example:
  bash submit_workshop_module.sh csv /scratch/user/mydata /scratch/user/results
  bash submit_workshop_module.sh images /scratch/user/images /scratch/user/results /scratch/user/fir_bundle/r-scripts 01:00:00 8G 2
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 3 ]; then
  usage >&2
  exit 1
fi

MODULE_KEY="$1"
INPUT_DIR="$(realpath "$2")"
OUTPUT_ROOT="$(realpath -m "$3")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R_SCRIPTS_DIR="${4:-${SCRIPT_DIR}/r-scripts}"
TIME_LIMIT="${5:-00:30:00}"
MEMORY="${6:-4G}"
CPUS="${7:-1}"

mkdir -p "${OUTPUT_ROOT}/logs"

sbatch \
  --job-name="curation_${MODULE_KEY}" \
  --time="${TIME_LIMIT}" \
  --cpus-per-task="${CPUS}" \
  --mem="${MEMORY}" \
  --output="${OUTPUT_ROOT}/logs/%x_%j.out" \
  --wrap="bash '${SCRIPT_DIR}/run_workshop_module.sh' '${MODULE_KEY}' '${INPUT_DIR}' '${OUTPUT_ROOT}' '${R_SCRIPTS_DIR}'"
