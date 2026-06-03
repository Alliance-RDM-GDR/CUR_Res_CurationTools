#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# One-time setup script for Fir.
# It loads R and installs the packages required by the workshop modules.

# Source the activation script so the loaded module and R paths remain
# available to the current shell before calling Rscript.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/activate_fir_r_env.sh"

Rscript - <<'EOF'
options(repos = c(CRAN = "https://cloud.r-project.org"))

lib <- Sys.getenv("R_LIBS_USER")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)

packages <- c(
  "tidyverse",
  "readr",
  "skimr",
  "magick",
  "exiftoolr",
  "digest",
  "hdf5r",
  "tidync",
  "ncmeta",
  "pdftools",
  "DBI",
  "RSQLite"
)

installed <- rownames(installed.packages(lib.loc = c(lib, .libPaths())))
missing <- setdiff(packages, installed)

cat("R library path:", lib, "\n")
if (length(missing) == 0) {
  cat("All required packages are already installed.\n")
} else {
  cat("Installing missing packages:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, lib = lib)
}
EOF

cat <<'EOF'

Environment setup finished.

If one package fails to compile, keep the full error log.
The most likely packages to need extra system support are:
- magick
- pdftools
- hdf5r
- tidync / ncmeta

EOF
