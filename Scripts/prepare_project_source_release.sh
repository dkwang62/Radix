#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

"${SCRIPT_DIR}/refresh_project_source_zip.sh"
"${SCRIPT_DIR}/verify_project_source_zip.sh"

echo
echo "Release source package manifest:"
cat "${PROJECT_ROOT}/Resources/RadixProjectSourceManifest.json"
