#!/usr/bin/env bash
set -euo pipefail

# Fetch the x86_64 Linux build used by merge_gopro.sh.
VERSION="v0.1.11"
URL="https://github.com/gyroflow/mp4-merge/releases/download/${VERSION}/mp4_merge-linux64"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mp4_merge-linux64"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required to download the merger." >&2
  exit 1
fi

curl -fL "$URL" -o "$DEST"
chmod +x "$DEST"
echo "Installed Linux merger at $DEST"
