#!/bin/bash
#######################################################
# PlayCover Manager
# macOS Sequoia 15.1+ Compatible
# Version: 5.2.0
#
# Bash/Zsh Compatible Entry Point
#######################################################

# Get script directory (bash/zsh compatible)
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback for zsh
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Execute main.sh (which loads all modules and runs the application)
# Single instance checking is handled by main.sh itself
if [[ -n "$BASH_VERSION" ]]; then
    bash "${SCRIPT_DIR}/main.sh"
else
    exec "${SCRIPT_DIR}/main.sh"
fi
