#!/usr/bin/env bash
# Imbai Worker — client install from GitHub
# Platform: https://imbacloud.ru/
# Repo:    https://github.com/array05/IMBACLOUD-AI

set -euo pipefail

IMBAI_GITHUB="${IMBAI_GITHUB:-https://github.com/array05/IMBACLOUD-AI}"
IMBAI_VERSION="${IMBAI_VERSION:-main}"
IMBAI_INSTALL_DIR="${IMBAI_INSTALL_DIR:-/opt/imbai}"

echo "==> Imbai Worker installer"
echo "    repo: ${IMBAI_GITHUB}"
echo "    dir:  ${IMBAI_INSTALL_DIR}"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl required" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ARCHIVE_URL="${IMBAI_GITHUB}/archive/refs/heads/${IMBAI_VERSION}.tar.gz"
echo "==> Downloading ${ARCHIVE_URL}"

if ! curl -fsSL "$ARCHIVE_URL" | tar xz -C "$TMP" --strip-components=1; then
  echo "Error: download failed. Set IMBAI_GITHUB to your public repo URL." >&2
  exit 1
fi

mkdir -p "$IMBAI_INSTALL_DIR"
rsync -a "$TMP/" "$IMBAI_INSTALL_DIR/"

echo "==> Running install-worker.sh"
exec "$IMBAI_INSTALL_DIR/scripts/install-worker.sh" "$@"
