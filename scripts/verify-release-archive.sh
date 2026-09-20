#!/bin/bash

set -u

archive_path="${1:-}"
require_distribution="${2:-}"
failures=0
warnings=0

if [[ -z "$archive_path" || ! -d "$archive_path" ]]; then
  echo "Usage: $0 /path/to/Graviti.xcarchive [--require-distribution]"
  exit 2
fi

app_path="$archive_path/Products/Applications/graviti.app"
extension_path="$app_path/PlugIns/GravitiShareExtension.appex"

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

warn() {
  echo "WARN: $1"
  warnings=$((warnings + 1))
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

expect_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local label="$4"
  local actual
  actual="$(plist_value "$plist" "$key")"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label is $expected"
  else
    fail "$label expected '$expected', found '${actual:-missing}'"
  fi
}

if [[ ! -d "$app_path" ]]; then
  echo "FAIL: app bundle not found at $app_path"
  exit 1
fi

if [[ ! -d "$extension_path" ]]; then
  echo "FAIL: Share Extension not found at $extension_path"
  exit 1
fi

app_info="$app_path/Info.plist"
extension_info="$extension_path/Info.plist"

expect_value "$app_info" "CFBundleIdentifier" "com.rhysgilk.graviti" "App bundle identifier"
expect_value "$extension_info" "CFBundleIdentifier" "com.rhysgilk.graviti.ShareExtension" "Extension bundle identifier"
expect_value "$app_info" "MinimumOSVersion" "18.0" "App minimum iOS version"
expect_value "$extension_info" "MinimumOSVersion" "18.0" "Extension minimum iOS version"

app_version="$(plist_value "$app_info" "CFBundleShortVersionString")"
extension_version="$(plist_value "$extension_info" "CFBundleShortVersionString")"
app_build="$(plist_value "$app_info" "CFBundleVersion")"
extension_build="$(plist_value "$extension_info" "CFBundleVersion")"

if [[ -n "$app_version" && "$app_version" == "$extension_version" ]]; then
  pass "App and extension marketing versions match ($app_version)"
else
  fail "App version '${app_version:-missing}' does not match extension version '${extension_version:-missing}'"
fi

if [[ -n "$app_build" && "$app_build" == "$extension_build" ]]; then
  pass "App and extension build numbers match ($app_build)"
else
  fail "App build '${app_build:-missing}' does not match extension build '${extension_build:-missing}'"
fi

encryption_value="$(plist_value "$app_info" "ITSAppUsesNonExemptEncryption")"
if [[ "$encryption_value" == "false" ]]; then
  pass "Non-exempt encryption is disabled"
else
  fail "ITSAppUsesNonExemptEncryption expected false, found '${encryption_value:-missing}'"
fi

for privacy_manifest in "$app_path/PrivacyInfo.xcprivacy" "$extension_path/PrivacyInfo.xcprivacy"; do
  if [[ -f "$privacy_manifest" ]] && plutil -lint "$privacy_manifest" >/dev/null; then
    pass "Privacy manifest is present and valid: ${privacy_manifest#$app_path/}"
  else
    fail "Missing or invalid privacy manifest: $privacy_manifest"
  fi
done

font_list="$(find "$app_path" -maxdepth 1 -type f \( -name '*.ttf' -o -name '*.otf' \) -exec basename {} \; | sort)"
expected_fonts=$'Sora-Regular.ttf\nSora-SemiBold.ttf'
if [[ "$font_list" == "$expected_fonts" ]]; then
  pass "Archive contains exactly the two registered Sora fonts"
else
  fail "Unexpected bundled fonts: ${font_list:-none}"
fi

csv_count="$(find "$app_path" -type f -name '*.csv' | wc -l | tr -d ' ')"
if [[ "$csv_count" == "0" ]]; then
  pass "Archive contains no CSV test fixtures"
else
  fail "Archive contains $csv_count CSV file(s)"
fi

if codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
  pass "App and nested code signatures are valid"
else
  fail "Code signature verification failed"
fi

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/graviti-archive-check.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

codesign -d --entitlements :- "$app_path" > "$temp_dir/app-entitlements.plist" 2>/dev/null
codesign -d --entitlements :- "$extension_path" > "$temp_dir/extension-entitlements.plist" 2>/dev/null

app_group="$(plist_value "$temp_dir/app-entitlements.plist" "com.apple.security.application-groups:0")"
extension_group="$(plist_value "$temp_dir/extension-entitlements.plist" "com.apple.security.application-groups:0")"
if [[ "$app_group" == "group.com.rhysgilk.graviti" && "$extension_group" == "$app_group" ]]; then
  pass "App and extension share the expected App Group"
else
  fail "App Group mismatch (app='${app_group:-missing}', extension='${extension_group:-missing}')"
fi

profile_path="$app_path/embedded.mobileprovision"
if [[ -f "$profile_path" ]] && security cms -D -i "$profile_path" > "$temp_dir/profile.plist" 2>/dev/null; then
  profile_name="$(plist_value "$temp_dir/profile.plist" "Name")"
  get_task_allow="$(plist_value "$temp_dir/profile.plist" "Entitlements:get-task-allow")"
  provisioned_devices="$(plist_value "$temp_dir/profile.plist" "ProvisionedDevices" || true)"
  if [[ "$get_task_allow" == "false" && -z "$provisioned_devices" ]]; then
    pass "Provisioning profile is eligible for distribution ($profile_name)"
  elif [[ "$require_distribution" == "--require-distribution" ]]; then
    fail "Provisioning profile is for development, not TestFlight upload ($profile_name)"
  else
    warn "Provisioning profile is for development; use --require-distribution for the upload gate ($profile_name)"
  fi
else
  fail "Embedded provisioning profile could not be decoded"
fi

signing_identity="$(plist_value "$archive_path/Info.plist" "ApplicationProperties:SigningIdentity")"
echo "INFO: Archive version $app_version ($app_build)"
echo "INFO: Signing identity ${signing_identity:-unknown}"
echo "INFO: $failures failure(s), $warnings warning(s)"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi

exit 0
