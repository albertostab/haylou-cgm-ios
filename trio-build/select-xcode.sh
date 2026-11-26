#!/bin/bash
set -euo pipefail
for candidate in /Applications/Xcode_26.5.app /Applications/Xcode_26.2.app /Applications/Xcode.app; do
  if [ -d "$candidate/Contents/Developer" ]; then
    sudo xcode-select -s "$candidate/Contents/Developer"
    xcodebuild -version
    xcrun --sdk iphoneos --show-sdk-version
    exit 0
  fi
done
echo 'No expected Xcode installation found.' >&2
exit 1
