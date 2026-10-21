#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iOS project generation/build requires macOS with Xcode 16 or newer.' >&2
  echo 'The portable core can be tested on Linux with swift test.' >&2
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo 'Install XcodeGen with: brew install xcodegen' >&2
  exit 1
fi
xcodebuild -version
xcodegen generate --spec "$repo_root/ios/project.yml"
printf '\nGenerated %s/ios/Lutli.xcodeproj\n' "$repo_root"
echo 'Open the project in Xcode and select your own signing team for device builds.'
