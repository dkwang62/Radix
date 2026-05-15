#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
ZIP_PATH="${PROJECT_ROOT}/Resources/RadixProjectSource.zip"
MANIFEST_PATH="${PROJECT_ROOT}/Resources/RadixProjectSourceManifest.json"

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "Missing ${ZIP_PATH}" >&2
  exit 1
fi

if [[ ! -f "${MANIFEST_PATH}" ]]; then
  echo "Missing ${MANIFEST_PATH}" >&2
  exit 1
fi

expected_bytes="$(/usr/bin/sed -n 's/.*"byteCount": \([0-9][0-9]*\).*/\1/p' "${MANIFEST_PATH}")"
expected_sha="$(/usr/bin/sed -n 's/.*"sha256": "\([0-9a-fA-F]*\)".*/\1/p' "${MANIFEST_PATH}" | /usr/bin/tr '[:upper:]' '[:lower:]')"

actual_bytes="$(/usr/bin/stat -f%z "${ZIP_PATH}")"
actual_sha="$(/usr/bin/shasum -a 256 "${ZIP_PATH}" | /usr/bin/awk '{print $1}')"

if [[ -z "${expected_bytes}" || -z "${expected_sha}" ]]; then
  echo "Manifest is missing byteCount or sha256." >&2
  exit 1
fi

if [[ "${actual_bytes}" != "${expected_bytes}" ]]; then
  echo "Byte count mismatch: expected ${expected_bytes}, got ${actual_bytes}" >&2
  exit 1
fi

if [[ "${actual_sha}" != "${expected_sha}" ]]; then
  echo "SHA-256 mismatch: expected ${expected_sha}, got ${actual_sha}" >&2
  exit 1
fi

echo "RadixProjectSource.zip verified (${actual_bytes} bytes, sha256 ${actual_sha})"
