#!/usr/bin/env bash
# Select the newest *stable* Xcode on the runner. Runner images gain beta
# and RC Xcodes without notice; picking those by "latest" turns an image
# update into a red build that has nothing to do with our code.
#
# Set XCODE_VERSION (e.g. "26.3") to pin an exact version instead.

set -euo pipefail

if [ -n "${XCODE_VERSION:-}" ]; then
  CANDIDATE="/Applications/Xcode_${XCODE_VERSION}.app"
  [ -d "$CANDIDATE" ] || { echo "::error::Xcode $XCODE_VERSION is not installed on this runner" >&2; ls -d /Applications/Xcode*.app >&2; exit 1; }
else
  CANDIDATE=$(ls -d /Applications/Xcode_*.app 2>/dev/null \
    | grep -viE 'beta|_rc|release.?candidate' \
    | sort -V | tail -n1)
  [ -n "$CANDIDATE" ] || { echo "::error::No stable Xcode found on this runner" >&2; ls -d /Applications/Xcode*.app >&2; exit 1; }
fi

echo "Selecting $CANDIDATE"
sudo xcode-select -s "$CANDIDATE"
xcodebuild -version
