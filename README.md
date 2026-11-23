# Merge GoPro split videos

This repository provides one script for GoPro Hero 5 and Hero 7 split MP4 files. It detects the camera from the filenames and chooses the bundled merger for the machine it is running on.

## Requirements

- Bash and standard command-line utilities (`awk`, `sort`, `cut`, `tr`).
- Apple Silicon Mac (M1/arm64): the existing binary in `mac/mp4_merge-mac-arm64`.
- Debian/Linux x86_64 (such as an Intel i3-9100T): `linux/mp4_merge-linux64`. Run `bash linux/download_binary.sh` to fetch the v0.1.11 Linux binary from [gyroflow/mp4-merge](https://github.com/gyroflow/mp4-merge/releases/tag/v0.1.11) into the expected location.

## Usage

```bash
chmod +x merge_gopro.sh
./merge_gopro.sh "/path/to/GoPro folder"
```

Supported camera filename patterns:

- Hero 5: `GOPR####.MP4` and `GPcc####.MP4`
- Hero 7: `GXcc####.MP4`

The script orders chunks by chapter, merges multi-part sequences without transcoding, and copies a single-part recording to its corresponding `_joined.mp4` output. Keep Hero 5 and Hero 7 files in separate input directories. The script refuses to process a directory containing both filename patterns.

The output files are written alongside the source videos. Ensure there is enough free disk space for the merged output.
