#!/usr/bin/env bash
set -euo pipefail

# Usage: merge_gopro.sh [--delete-originals] <directory-with-gopro-mp4-files>
# Supports GoPro Hero 5 (GOPR#### / GPcc####) and Hero 7 (GXcc####).
# Selects the bundled merger for Apple Silicon macOS or x86_64 Linux.
# Original input files are kept unless --delete-originals is explicitly passed.

DELETE_ORIGINALS=0
if [[ "${1:-}" == "--delete-originals" ]]; then
  DELETE_ORIGINALS=1
  shift
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 [--delete-originals] <directory-with-gopro-mp4-files>" >&2
  exit 1
fi

INPUT_DIR="$1"
if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: not a directory: $INPUT_DIR" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
ARCH="$(uname -m)"
case "$OS:$ARCH" in
  Darwin:arm64|Darwin:aarch64)
    MERGER="$SCRIPT_DIR/mac/mp4_merge-mac-arm64"
    ;;
  Linux:x86_64|Linux:amd64)
    MERGER="$SCRIPT_DIR/linux/mp4_merge-linux64"
    ;;
  *)
    echo "Error: unsupported platform $OS/$ARCH (supported: Apple Silicon macOS and x86_64 Linux)." >&2
    exit 1
    ;;
esac

if [ ! -x "$MERGER" ]; then
  echo "Error: merger binary missing or not executable: $MERGER" >&2
  echo "See README.md for installation instructions." >&2
  exit 1
fi

shopt -s nullglob
mp4_list=( "$INPUT_DIR"/*.[mM][pP]4 )
if [ "${#mp4_list[@]}" -eq 0 ]; then
  echo "No MP4 files found in $INPUT_DIR"
  exit 0
fi

hero5=0
hero7=0
for f in "${mp4_list[@]}"; do
  name="${f##*/}"
  upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
  if [[ "$upper" =~ ^GOPR[0-9]{4}\.MP4$ || "$upper" =~ ^GP[0-9]{6}\.MP4$ ]]; then
    hero5=1
  elif [[ "$upper" =~ ^GX[0-9]{6}\.MP4$ ]]; then
    hero7=1
  fi
done

if [ "$hero5" -eq 1 ] && [ "$hero7" -eq 1 ]; then
  echo "Error: this directory contains both Hero 5 and Hero 7 filename patterns; process them separately." >&2
  exit 1
elif [ "$hero5" -eq 1 ]; then
  camera=hero5
elif [ "$hero7" -eq 1 ]; then
  camera=hero7
else
  echo "Error: no recognized Hero 5 (GOPR####/GPcc####) or Hero 7 (GXcc####) filenames found." >&2
  exit 1
fi

echo "Detected $camera input on $OS/$ARCH."
if [ "$DELETE_ORIGINALS" -eq 1 ]; then
  echo "WARNING: --delete-originals is enabled; source files will be removed only after a non-empty output is successfully created."
fi

# Keep temporary lists and staged outputs on the input filesystem, so publishing
# a completed output uses a same-filesystem rename.
WORK_DIR="$(mktemp -d "$INPUT_DIR/.merge_gopro.XXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT

for f in "${mp4_list[@]}"; do
  name="${f##*/}"
  upper="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"

  if [ "$camera" = hero5 ]; then
    if [[ "$upper" =~ ^GOPR([0-9]{4})\.MP4$ ]]; then
      seq="${BASH_REMATCH[1]}"
      chapter=0
    elif [[ "$upper" =~ ^GP([0-9]{2})([0-9]{4})\.MP4$ ]]; then
      chapter="${BASH_REMATCH[1]}"
      seq="${BASH_REMATCH[2]}"
      chapter=$((10#$chapter))
    else
      continue
    fi
  else
    if [[ "$upper" =~ ^GX([0-9]{2})([0-9]{4})\.MP4$ ]]; then
      chapter="${BASH_REMATCH[1]}"
      seq="${BASH_REMATCH[2]}"
    else
      continue
    fi
    chapter=$((10#$chapter))
  fi
  printf '%d\t%s\n' "$chapter" "$f" >> "$WORK_DIR/seq_$seq"
done

created=0
failed=0
for seqfile in "$WORK_DIR"/seq_*; do
  [ -f "$seqfile" ] || continue
  seq="${seqfile##*_}"
  sorted="$seqfile.sorted"
  awk -F '\t' '!seen[$2]++ { print $0 }' "$seqfile" | sort -n -t$'\t' -k1,1 > "$sorted"
  paths=()
  while IFS= read -r p; do
    paths+=("$p")
  done < <(cut -f2 -d$'\t' "$sorted")

  if [ "${#paths[@]}" -eq 0 ]; then
    rm -f -- "$sorted"
    continue
  fi

  if [ "$camera" = hero5 ]; then
    outname="GOPR${seq}_joined.mp4"
  else
    outname="GX${seq}_joined.mp4"
  fi
  outpath="$INPUT_DIR/$outname"
  sequence_ok=0

  if [ "$DELETE_ORIGINALS" -eq 1 ] && [ -e "$outpath" ]; then
    echo "Error: refusing to replace existing output while --delete-originals is enabled: $outpath" >&2
    failed=1
  elif [ "${#paths[@]}" -gt 1 ]; then
    echo "Merging sequence $seq:"
    for p in "${paths[@]}"; do printf '  %s\n' "$p"; done
    if [ "$DELETE_ORIGINALS" -eq 1 ]; then
      merge_out="$WORK_DIR/$outname"
    else
      merge_out="$outpath"
    fi
    if "$MERGER" "${paths[@]}" --out "$merge_out"; then
      if [ -s "$merge_out" ]; then
        if [ "$DELETE_ORIGINALS" -eq 1 ]; then
          if mv -- "$merge_out" "$outpath"; then
            sequence_ok=1
          else
            echo "Error publishing output for sequence $seq; originals kept." >&2
            failed=1
          fi
        else
          sequence_ok=1
        fi
        if [ "$sequence_ok" -eq 1 ]; then
          echo "Created $(basename "$outpath")"
        fi
      else
        echo "Error: merger reported success but produced no non-empty output for sequence $seq; originals kept." >&2
        failed=1
      fi
    else
      rc=$?
      echo "Error merging sequence $seq (exit code $rc); originals kept." >&2
      failed=1
    fi
  else
    echo "Copying single-part sequence to $(basename "$outpath")"
    if [ "$DELETE_ORIGINALS" -eq 1 ]; then
      copy_out="$WORK_DIR/$outname"
    else
      copy_out="$outpath"
    fi
    if cp -p -- "${paths[0]}" "$copy_out"; then
      if [ -s "$copy_out" ]; then
        if [ "$DELETE_ORIGINALS" -eq 1 ]; then
          if mv -- "$copy_out" "$outpath"; then
            sequence_ok=1
          else
            echo "Error publishing copied output for sequence $seq; original kept." >&2
            failed=1
          fi
        else
          sequence_ok=1
        fi
      else
        echo "Error: copied output is empty for sequence $seq; original kept." >&2
        failed=1
      fi
    else
      rc=$?
      echo "Error copying sequence $seq (exit code $rc); original kept." >&2
      failed=1
    fi
  fi

  if [ "$sequence_ok" -eq 1 ]; then
    created=$((created + 1))
    if [ "$DELETE_ORIGINALS" -eq 1 ]; then
      echo "Removing source file(s) for successfully created $(basename "$outpath")."
      if ! rm -- "${paths[@]}"; then
        echo "Error removing one or more source files for sequence $seq." >&2
        failed=1
      fi
    fi
  fi
  rm -f -- "$sorted"
done

echo "Processing complete. Created or copied $created merged video file(s)."
exit "$failed"
