#!/bin/bash

eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="/opt/homebrew/bin:${PATH}"

${HOME}/bin/claude-image-renamer.sh "$@" >> /tmp/claude-image-renamer.log 2>&1

