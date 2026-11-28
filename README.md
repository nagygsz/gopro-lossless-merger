# Merge GoPro split videos

This repository provides one script for GoPro Hero 5 and Hero 7 split MP4 files. It detects the camera from the filenames and selects the bundled merger for the host operating system.

## Requirements

- Bash and standard command-line utilities (`awk`, `sort`, `cut`, `tr`).
- Apple Silicon macOS or x86_64 Linux.
- The appropriate bundled merger binary:
  - macOS: `mac/mp4_merge-mac-arm64`
  - Linux: `linux/mp4_merge-linux64`

## Usage

Keep the default behavior to preserve all source videos:

```bash
./merge_gopro.sh "/path/to/GoPro folder"
```

For a single-part sequence, the script uses a same-directory rename instead of copying it. For multi-part sequences, it merges the parts as usual.

To remove recognized source video files after each sequence has produced a successful, non-empty output, explicitly opt in:

```bash
./merge_gopro.sh --delete-originals "/path/to/GoPro folder"
```

With `--delete-originals`, the script refuses to replace an already-existing `_joined.mp4` output. Source files for that sequence are removed only after the new output is successfully created and published. If merging, copying, or publishing fails, source files are kept. Deletion is permanent; make and verify a backup before using this option.

Supported camera filename patterns:

- Hero 5: `GOPR####.MP4` and `GPcc####.MP4`
- Hero 7: `GXcc####.MP4`

The script orders chunks by chapter, merges multi-part sequences without transcoding, and renames single-part recordings to their corresponding `_joined.mp4` output. Keep Hero 5 and Hero 7 files in separate directories. Output files are written alongside the source videos; ensure there is enough free disk space.
