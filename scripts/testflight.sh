#!/bin/zsh
# Archive a Release build and upload it to App Store Connect, where it lands in TestFlight.
#
# The build number is the archive time, YYYYMMDD.HHMM (e.g. 20261008.1542), so every upload
# is higher than the last. The version (MARKETING_VERSION in project.yml) is left alone.
#
# Usage:
#   scripts/testflight.sh            archive and upload
#   scripts/testflight.sh --no-upload  archive only
#
# Uploading uses the Apple account signed in to Xcode (Settings > Accounts).

set -euo pipefail

cd "$(dirname "$0")/.."

upload=true
if [[ "${1:-}" == "--no-upload" ]]; then
  upload=false
elif [[ $# -gt 0 ]]; then
  echo "usage: $0 [--no-upload]" >&2
  exit 64
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "warning: working tree has uncommitted changes; they will be in this build." >&2
fi

# Read the date and time once so both halves come from the same moment.
# The time is written without leading zeros (09:05 -> 905) because each part of a
# build number must be a plain integer.
read day hhmm <<< "$(date '+%Y%m%d %H%M')"
build_number="$day.$((10#$hhmm))"

# Tidy xcodebuild's output when xcbeautify is installed (brew install xcbeautify).
pretty() {
  if command -v xcbeautify > /dev/null; then xcbeautify; else cat; fi
}

build_dir="build/testflight/$build_number"
archive_path="$build_dir/WearToday.xcarchive"
export_options="$build_dir/ExportOptions.plist"
mkdir -p "$build_dir"

echo "==> Archiving WearToday build $build_number"
xcodebuild archive \
  -project WearToday.xcodeproj \
  -scheme WearToday \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$build_number" \
  | pretty

if ! $upload; then
  echo "==> Archived to $archive_path (not uploaded)"
  exit 0
fi

cat > "$export_options" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>TYXC29FT67</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST

echo "==> Uploading build $build_number to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$build_dir/export" \
  -allowProvisioningUpdates \
  | pretty

echo "==> Uploaded build $build_number. It appears in TestFlight once App Store Connect finishes processing (usually 5-30 minutes)."
