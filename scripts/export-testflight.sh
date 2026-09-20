#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
archive_path="${1:-}"
export_path="${2:-/tmp/graviti-testflight-export-$(date +%Y%m%d-%H%M%S)}"

if [[ -z "$archive_path" || "$archive_path" == "--help" || "$archive_path" == "-h" ]]; then
  echo "Usage: $0 /path/to/graviti.xcarchive [/path/to/export-directory]"
  echo
  echo "Creates a locally exported App Store Connect IPA. It does not upload the app."
  exit 0
fi

if [[ ! -d "$archive_path" ]]; then
  echo "Archive not found: $archive_path" >&2
  exit 2
fi

if [[ -e "$export_path" ]]; then
  echo "Export destination already exists: $export_path" >&2
  echo "Choose a new empty path so an older IPA cannot be mistaken for this export." >&2
  exit 2
fi

"$script_dir/verify-release-archive.sh" "$archive_path"

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/graviti-testflight-export.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

cat > "$temp_dir/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>V9W8HRDJQT</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DEVELOPER_DIR="$developer_dir" xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$export_path" \
  -exportOptionsPlist "$temp_dir/ExportOptions.plist" \
  -allowProvisioningUpdates

ipa_path="$(find "$export_path" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
if [[ -z "$ipa_path" ]]; then
  echo "Export completed without producing an IPA in $export_path" >&2
  exit 1
fi

echo "TestFlight IPA exported to: $ipa_path"
echo "The IPA has not been uploaded."
