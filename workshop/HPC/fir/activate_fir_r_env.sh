#!/bin/bash
set -euo pipefail

R_MODULE_CANDIDATES=(
  "${R_MODULE:-}"
  "r/4.4.1"
  "r/4.4.0"
  "r/4.4"
  "r/4.3.3"
  "r/4.3.2"
  "r/4.3"
)

init_modules() {
  if command -v module >/dev/null 2>&1; then
    return 0
  fi

  if [ -f /etc/profile.d/modules.sh ]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
    return 0
  fi

  return 1
}

load_first_available_module() {
  local module_name
  for module_name in "${R_MODULE_CANDIDATES[@]}"; do
    [ -z "${module_name}" ] && continue
    if module load "${module_name}" >/dev/null 2>&1; then
      echo "Loaded R module: ${module_name}"
      return 0
    fi
  done

  echo "Could not load an R module automatically." >&2
  echo "Set R_MODULE before running, for example: export R_MODULE=r/4.4.1" >&2
  return 1
}

if ! init_modules; then
  echo "Environment Modules is not available in this shell." >&2
  exit 1
fi

module purge >/dev/null 2>&1 || true
module load StdEnv/2023 >/dev/null 2>&1 || true
load_first_available_module

export R_LIBS_USER="${R_LIBS_USER:-${HOME}/R/fir-library}"
mkdir -p "${R_LIBS_USER}"

echo "R_LIBS_USER=${R_LIBS_USER}"
