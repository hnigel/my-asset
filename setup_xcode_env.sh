#!/bin/bash

# Setup Xcode environment for my asset project
# This script resolves the persistent Xcode developer directory issue

echo "Setting up Xcode environment..."

# Set developer directory for current session
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

echo "Current developer directory: $(xcode-select --print-path)"
echo "Corrected developer directory: $DEVELOPER_DIR"

# Test xcodebuild
echo "Testing xcodebuild..."
xcodebuild -version

# Open the project
echo "Opening my asset project in Xcode..."
open "my asset/my asset.xcodeproj"

echo "Xcode environment setup complete!"
echo ""
echo "To use this permanently, add this to your ~/.zshrc or ~/.bash_profile:"
echo 'export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"'