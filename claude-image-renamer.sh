#!/usr/bin/env bash
#
# AI-powered image renaming script that generates descriptive filenames for screenshots.
# Uses OCR text extraction combined with Claude's vision capabilities to analyze image
# content and rename files to a searchable, lowercase, underscore-separated format.
#
# Usage: ./claude-image-renamer.sh <image_file>
#
# Dependencies:
#   - ocr: for text extraction from images
#   - claude: Claude Code CLI for AI-powered analysis
#
# Workflow:
#   1. Sanitize macOS screenshot filenames containing narrow no-break space (U+202F)
#   2. Generate OCR text extraction (or use existing .ocr.txt file)
#   3. Send OCR content and image to Claude for analysis
#   4. Claude renames the file using mv to a descriptive format

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

# macOS screenshots contain narrow no-break space (U+202F) between date and time
# components, which causes issues with shell processing. We detect and sanitize
# these filenames to: screenshot_YYYYMMDD.HHMMSS.<ext>
readonly NARROW_NBSP=$'\xE2\x80\xAF'

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

validate_input_file() {
    local file_path="$1"

    if [[ ! -e "${file_path}" ]]; then
        echo "File not found: ${file_path}" >&2
        exit 1
    fi
}

sanitize_macos_screenshot_name() {
    # Renames macOS screenshot files that contain the narrow no-break space
    # character (U+202F) to a cleaner format: screenshot_YYYYMMDD.HHMMSS.<ext>
    #
    # Args:
    #   $1: input file path
    #
    # Returns:
    #   The sanitized file path (or original if no sanitization needed)

    local input_file="$1"

    if [[ "${input_file}" != *"${NARROW_NBSP}"* ]]; then
        echo "${input_file}"
        return
    fi

    local dir ext timestamp new_path
    dir=$(dirname "${input_file}")
    ext="${input_file##*.}"
    timestamp=$(stat -f "%SB" -t "%Y%m%d.%H%M%S" "${input_file}")
    new_path="${dir}/screenshot_${timestamp}.${ext}"

    mv "${input_file}" "${new_path}"
    echo "Renamed: ${input_file} -> screenshot_${timestamp}.${ext}" >&2

    echo "${new_path}"
}

get_or_create_ocr_file() {
    # Returns the path to the OCR text file, creating it if necessary.
    # If the ocr binary is not available, creates a placeholder file instead.
    #
    # Args:
    #   $1: input image file path
    #
    # Returns:
    #   Path to the .ocr.txt file

    local input_file="$1"
    local ocr_file="${input_file%%.*}.ocr.txt"

    if [[ ! -e "${ocr_file}" ]]; then
        if command -v ocr > /dev/null 2>&1; then
            ocr "${input_file}" >| "${ocr_file}"
        else
            echo "Warning: ocr binary not found, proceeding without OCR content" >&2
            echo "(Note to Claude: OCR content not available)" >| "${ocr_file}"
        fi
    fi

    echo "${ocr_file}"
}

build_rename_prompt() {
    # Constructs the prompt for Claude to analyze and rename the image.
    #
    # Args:
    #   $1: input file path
    #   $2: OCR text content
    #
    # Returns:
    #   The formatted prompt string

    local input_file="$1"
    local ocr_content="$2"

    cat <<EOF
Rename the file '${input_file}' to a descriptive lowercase filename.
Rules:
- Max 64 characters, max 10 words
- Only lowercase letters, numbers, and underscores
- Format: main_thing_sub_thing_detail
- Preserve the original file extension
- Do not overwrite or try to rename a file if the target file name already exists.

OCR text from the image:
${ocr_content}

Use mv to rename the file, then echo the new filename.
IMPORTANT: YOU MUST ACTUALLY RENAME THE FILE WITH THE ALLOWED TOOLS.
CRITICAL: If the target file name already exists, do not overwrite. Instead append a "_1", "_2", "_3", etc. at the end of the base file name.
EOF
}

rename_with_claude() {
    # Invokes Claude to analyze the image and rename it.
    #
    # Args:
    #   $1: input file path
    #   $2: OCR file path

    local input_file="$1"
    local ocr_file="$2"
    local ocr_content prompt

    ocr_content=$(cat "${ocr_file}")
    prompt=$(build_rename_prompt "${input_file}" "${ocr_content}")

    claude --model opus --allowedTools "Bash(mv:*)" -p "${prompt}"

    rm -f "${ocr_file}"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
    local input_file="$1"
    local ocr_file

    validate_input_file "${input_file}"
    input_file=$(sanitize_macos_screenshot_name "${input_file}")
    ocr_file=$(get_or_create_ocr_file "${input_file}")
    rename_with_claude "${input_file}" "${ocr_file}"
}

main "$1"
