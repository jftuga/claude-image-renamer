#!/usr/bin/env bash
#
# AI-powered image renaming script that generates descriptive filenames for screenshots.
# Uses OCR text extraction combined with Claude's vision capabilities to analyze image
# content and rename files to a searchable, lowercase, underscore-separated format.
#
# Usage: ./claude-image-renamer.sh <image_file> [image_file...]
#
# Dependencies:
#   - ocr: for text extraction from images
#   - claude: Claude Code CLI for AI-powered analysis
#
# Workflow:
#   For each image file provided:
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

show_usage() {
    # Displays usage information and exits with an error code.

    echo "Usage: $(basename "$0") <image_file> [image_file...]" >&2
    echo "Rename one or more image files using AI-powered descriptive naming." >&2
    exit 1
}

validate_input_file() {
    # Validates that the input file exists.
    #
    # Args:
    #   $1: file path to validate
    #
    # Returns:
    #   0 if file exists, 1 otherwise

    local file_path="$1"

    if [[ ! -e "${file_path}" ]]; then
        echo "Error: File not found: ${file_path}" >&2
        return 1
    fi

    return 0
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
    # save ocr_file to /tmp as to not trigger another Folder Action
    local basename="${input_file##*/}"
    local ocr_file="/tmp/${basename%%.*}.ocr.txt"

    if [[ ! -e "${ocr_file}" ]]; then
        if command -v ${HOME}/bin/ocr > /dev/null 2>&1; then
            ${HOME}/bin/ocr "${input_file}" >| "${ocr_file}"
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
    local dir
    dir=$(dirname "${input_file}")

    cat <<EOF
Rename the file '${input_file}' to a descriptive lowercase filename.

NAMING RULES:
- Maximum 64 characters total, maximum 10 words
- Only lowercase letters, numbers, and underscores (no spaces or hyphens)
- Format: main_thing_sub_thing_detail.ext
- Preserve the original file extension

OCR text from the image:
${ocr_content}

COLLISION DETECTION - MANDATORY STEPS:
1. First, determine your ideal descriptive base name (e.g., "tide" for tide.png)
2. BEFORE renaming, you MUST check if the target file already exists using: test -e "<target_path>"
3. If the file exists (exit code 0), you MUST increment the suffix:
   - If "tide.png" exists, try "tide_1.png"
   - If "tide_1.png" exists, try "tide_2.png"
   - Continue incrementing until you find a name that does NOT exist
4. You can also use: ls "${dir}/<base_name>*.png" 2>/dev/null to see all similar files
5. Only after confirming the target does NOT exist, run: mv "${input_file}" "<final_target_path>"

EXAMPLE WORKFLOW:
  # Check if tide.png exists
  test -e "${dir}/tide.png" && echo "exists" || echo "available"
  # If exists, check tide_1.png
  test -e "${dir}/tide_1.png" && echo "exists" || echo "available"
  # Once you find an available name, rename
  mv "${input_file}" "${dir}/tide_1.png"

After renaming, echo ONLY the new filename (not the full path).

CRITICAL: Do NOT assume a filename is available. You MUST verify with test -e before each mv command.
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

    echo "Uploading image to claude, please wait for reply..."
    ${$HOMEBREW_PREFIX}/bin/claude --model opus --allowedTools "Bash(mv:*)" "Bash(ls:*)" "Bash(test:*)" -p "${prompt}"

    rm -f "${ocr_file}"
}

process_single_file() {
    # Processes a single image file through the renaming workflow.
    #
    # Args:
    #   $1: input file path
    #
    # Returns:
    #   0 on success, 1 on failure

    local input_file="$1"
    local ocr_file

    if ! validate_input_file "${input_file}"; then
        return 1
    fi

    input_file=$(sanitize_macos_screenshot_name "${input_file}")
    ocr_file=$(get_or_create_ocr_file "${input_file}")
    rename_with_claude "${input_file}" "${ocr_file}"

    return 0
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
    if [[ $# -eq 0 ]]; then
        show_usage
    fi

    local file
    local success_count=0
    local failure_count=0
    local total_count=$#

    for file in "$@"; do
        # only operate on newly create MacOS screenshot files placed in ~/Desktop
        local basename="${file##*/}"
        if [[ "${basename}" != Screenshot*.png ]]; then
            continue
        fi

        echo "-----------------------------------------------------"
        echo "Processing: ${file}"
        echo "-----------------------------------------------------"

        if process_single_file "${file}"; then
            ((success_count++))
        else
            ((failure_count++))
        fi

        echo ""
    done

    if [[ ${total_count} -gt 1 ]]; then
        echo "=========================================="
        echo "Summary: ${success_count}/${total_count} files processed successfully"
        if [[ ${failure_count} -gt 0 ]]; then
            echo "         ${failure_count} file(s) failed"
        fi
        echo "=========================================="
    fi
}

main "$@"
