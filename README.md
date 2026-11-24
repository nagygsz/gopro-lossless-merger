# Merge GoPro split videos

This repository provides one script for GoPro Hero 5 and Hero 7 split MP4 files. It detects the camera from the filenames and selects the bundled merger for the host operating system.

## Requirements

- Bash and standard command-line utilities (`awk`, `sort`, `cut`, `tr`).
- Apple Silicon macOS or x86_64 Linux.
- The appropriate bundled merger binary:
  - macOS: `mac/mp4_merge-mac-arm64`
  - Linux: `linux/mp4_merge-linux64`

## Usage

```bash
chmod +x merge_gopro.sh mac/mp4_merge-mac-arm64 linux/mp4_merge-linux64
./merge_gopro.sh "/path/to/GoPro folder"
```

Supported camera filename patterns:

- Hero 5: `GOPR####.MP4` and `GPcc####.MP4`
- Hero 7: `GXcc####.MP4`

The script orders chunks by chapter, merges multi-part sequences without transcoding, and copies a single-part recording to its corresponding `_joined.mp4` output. Keep Hero 5 and Hero 7 files in separate directories.

Output files are written alongside the source videos. Ensure there is enough free disk space for the merged output.
