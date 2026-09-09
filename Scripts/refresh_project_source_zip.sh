#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
OUTPUT="${PROJECT_ROOT}/Resources/RadixProjectSource.zip"
MANIFEST="${PROJECT_ROOT}/Resources/RadixProjectSourceManifest.json"
GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
GENERATED_DISPLAY="$(date '+%Y-%m-%d %H:%M:%S %Z')"

cd "${PROJECT_ROOT}"

tmp_zip="${OUTPUT}.tmp"
tmp_dir="$(mktemp -d)"
rm -f "${tmp_zip}"
trap 'rm -rf "${tmp_dir}" "${tmp_zip}"' EXIT

cat > "${tmp_dir}/README_PROJECT_SOURCE.txt" <<EOF
Radix Project Source Package

This ZIP is the fixed Radix source package bundled with the app build. It is
intended for Advanced users who want a stable copy of the Xcode project and
source resources that shipped with this version of Radix.

Generated: ${GENERATED_DISPLAY}

To refresh this package before a release, run:

Scripts/refresh_project_source_zip.sh

Excluded from this package:
- .git
- .build
- DerivedData
- build folders
- Xcode user state
- xcuserdata
- .DS_Store
- Resources/RadixProjectSource.zip
- Resources/RadixProjectSourceManifest.json
EOF

zip -qr "${tmp_zip}" . \
  -x '.git/*' \
  -x '*/.git/*' \
  -x '.build/*' \
  -x '*/.build/*' \
  -x '.codex_write_test' \
  -x '*/.codex_write_test' \
  -x 'DerivedData/*' \
  -x '*/DerivedData/*' \
  -x 'build/*' \
  -x '*/build/*' \
  -x 'xcuserdata' \
  -x 'xcuserdata/*' \
  -x '*/xcuserdata' \
  -x '*/xcuserdata/*' \
  -x '*.xcuserstate' \
  -x '.DS_Store' \
  -x '*/.DS_Store' \
  -x 'Resources/RadixProjectSource.zip' \
  -x 'Resources/RadixProjectSource.zip.tmp' \
  -x 'Resources/RadixProjectSourceManifest.json' \
  -x 'RadixProjectSource.zip'

(
  cd "${tmp_dir}"
  zip -q "${tmp_zip}" README_PROJECT_SOURCE.txt
)

mv "${tmp_zip}" "${OUTPUT}"
ZIP_BYTES="$(stat -f%z "${OUTPUT}")"
ZIP_SHA256="$(shasum -a 256 "${OUTPUT}" | awk '{print $1}')"
cat > "${MANIFEST}" <<EOF
{
  "filename": "RadixProjectSource.zip",
  "generatedAt": "${GENERATED_AT}",
  "byteCount": ${ZIP_BYTES},
  "sha256": "${ZIP_SHA256}"
}
EOF

echo "Updated ${OUTPUT}"
echo "Updated ${MANIFEST}"
