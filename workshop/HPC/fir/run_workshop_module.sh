#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash run_workshop_module.sh <module> <input_dir> <output_root> [scripts_dir]

Modules:
  extensions | csv | images | hdf5 | nc | pdf | sqlite

Examples:
  bash run_workshop_module.sh csv /scratch/user/mydata /scratch/user/results
  bash run_workshop_module.sh nc /scratch/user/netcdf /scratch/user/results /scratch/user/fir_bundle/r-scripts
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

if [ ! -d "${INPUT_DIR}" ]; then
  echo "Input directory does not exist: ${INPUT_DIR}" >&2
  exit 1
fi

if [ ! -d "${R_SCRIPTS_DIR}" ]; then
  echo "R scripts directory does not exist: ${R_SCRIPTS_DIR}" >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/activate_fir_r_env.sh"

case "${MODULE_KEY}" in
  extensions)
    R_SCRIPT="Inspect_Extensions_Script.R"
    OUT_SUBDIR="Inspect_Extensions"
    MODE="pass-output"
    ;;
  csv)
    R_SCRIPT="Inspect_csv_Script.R"
    OUT_SUBDIR="Inspect_csv"
    MODE="pass-output"
    ;;
  images)
    R_SCRIPT="Inspect_Images_Script.R"
    OUT_SUBDIR="Inspect_Images"
    MODE="fixed-output"
    ;;
  hdf5)
    R_SCRIPT="Inspect_hdf5_Script.R"
    OUT_SUBDIR="Inspect_hdf5"
    MODE="pass-output"
    ;;
  nc)
    R_SCRIPT="Inspect_nc_Script.R"
    OUT_SUBDIR="Inspect_nc"
    MODE="fixed-output"
    ;;
  pdf)
    R_SCRIPT="Inspect_PDF_Script.R"
    OUT_SUBDIR="Inspect_pdf"
    MODE="fixed-output"
    ;;
  sqlite)
    R_SCRIPT="Inspect_sqlite_Script.R"
    OUT_SUBDIR="Inspect_sqlite"
    MODE="sqlite-output"
    ;;
  *)
    echo "Unsupported module: ${MODULE_KEY}" >&2
    exit 1
    ;;
esac

mkdir -p "${OUTPUT_ROOT}"
TARGET_OUTPUT="${OUTPUT_ROOT}/${OUT_SUBDIR}"
mkdir -p "${TARGET_OUTPUT}"

JOB_WORKDIR="${SLURM_TMPDIR:-${OUTPUT_ROOT}/work_${MODULE_KEY}_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "${JOB_WORKDIR}"

cp "${R_SCRIPTS_DIR}/${R_SCRIPT}" "${JOB_WORKDIR}/"

pushd "${JOB_WORKDIR}" >/dev/null

echo "Running module: ${MODULE_KEY}"
echo "Input:  ${INPUT_DIR}"
echo "Output: ${TARGET_OUTPUT}"
echo "Workdir: ${JOB_WORKDIR}"

case "${MODE}" in
  pass-output)
    Rscript "${R_SCRIPT}" "${INPUT_DIR}" "${TARGET_OUTPUT}"
    ;;
  sqlite-output)
    Rscript "${R_SCRIPT}" "${INPUT_DIR}" "${OUTPUT_ROOT}"
    ;;
  fixed-output)
    Rscript "${R_SCRIPT}" "${INPUT_DIR}"
    if [ -d "Results/${OUT_SUBDIR}" ]; then
      cp -R "Results/${OUT_SUBDIR}/." "${TARGET_OUTPUT}/"
    else
      echo "Expected output directory was not created: Results/${OUT_SUBDIR}" >&2
      exit 1
    fi
    ;;
esac

popd >/dev/null

echo "Module ${MODULE_KEY} completed."
echo "Results available in: ${TARGET_OUTPUT}"
