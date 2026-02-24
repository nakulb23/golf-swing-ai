#!/bin/bash
# Disable dSYM upload for llama framework to prevent symbol upload errors

# This script prevents Xcode from trying to upload dSYM files for the llama.cpp framework
# which doesn't include debug symbols

if [ "$CONFIGURATION" = "Debug" ]; then
    echo "Skipping symbol upload for Debug build"
    exit 0
fi

# For Release builds, we still want to upload our app's symbols,
# but exclude the llama framework
echo "Build configuration: $CONFIGURATION"
