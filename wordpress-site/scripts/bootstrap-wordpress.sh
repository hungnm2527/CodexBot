#!/usr/bin/env bash
set -euo pipefail

# Download and extract the requested WordPress version into this project directory
# while preserving the existing wp-content folder.

WP_VERSION="${WP_VERSION:-latest}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
ARCHIVE_NAME="wordpress-${WP_VERSION}.zip"
DOWNLOAD_URL="https://wordpress.org/${WP_VERSION}.zip"

if [[ "${WP_VERSION}" == "latest" ]]; then
  ARCHIVE_NAME="wordpress-latest.zip"
  DOWNLOAD_URL="https://wordpress.org/latest.zip"
else
  ARCHIVE_NAME="wordpress-${WP_VERSION}.zip"
  DOWNLOAD_URL="https://wordpress.org/wordpress-${WP_VERSION}.zip"
fi

echo "Downloading WordPress package: ${DOWNLOAD_URL}" >&2
curl -fL "${DOWNLOAD_URL}" -o "${TMP_DIR}/${ARCHIVE_NAME}"

unzip -q "${TMP_DIR}/${ARCHIVE_NAME}" -d "${TMP_DIR}"

rsync -a --delete --exclude=wp-content "${TMP_DIR}/wordpress/" "${PROJECT_ROOT}/"

echo "WordPress core files have been staged in ${PROJECT_ROOT}. Existing wp-content was preserved." >&2
