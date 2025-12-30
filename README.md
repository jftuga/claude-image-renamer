# claude-image-renamer

AI-powered image renaming script that generates descriptive filenames for screenshots. Uses OCR text extraction combined with Claude's vision capabilities to analyze image content and rename files to a searchable, lowercase, underscore-separated format.

## Features

- Automatically sanitizes macOS screenshot filenames containing special Unicode characters
- Extracts text from images via OCR to improve rename accuracy
- Uses Claude AI to analyze both the image and extracted text
- Generates clean, descriptive filenames (max 64 characters, lowercase with underscores)

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`claude`)
- `ocr` binary (optional, macOS only)

## Installation

```bash
git clone https://github.com/jftuga/claude-image-renamer.git
cd claude-image-renamer
chmod 755 claude-image-renamer.sh
```

To build the optional OCR tool (macOS only):
* This compiles `ocr.swift` using the macOS Vision framework. The script will function without the `ocr` binary, but providing OCR text improves Claude's ability to generate accurate filenames.

```bash
make
```

## Usage Example

```bash
./claude-image-renamer.sh "Screenshot 2025-12-29 at 10.03.10 PM.png"
# Renames to something like: vscode_python_debug_settings.png
```

## How It Works

1. Sanitizes macOS screenshot filenames that contain narrow no-break space characters (U+202F)
2. Generates OCR text extraction from the image (or uses existing `.ocr.txt` file if present)
3. Sends both the OCR content and image to Claude for analysis
4. Claude renames the file to a descriptive format using `mv`

## Acknowledgements

A few ideas in this script were derived from [ai-screenshot-namer](https://github.com/cpbotha/ai-screenshot-namer)

