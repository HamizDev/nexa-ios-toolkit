#!/usr/bin/env bash
# Nexa 0.0.1: signed local iPhone + embedded Watch archive/export.
# Requires an owner-configured Apple Developer team and a macOS Xcode toolchain.
# Never embeds credentials or provisioning profiles in the public repository.
set -euo pipefail

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == "Darwin" ]] || fail "Run on macOS with Xcode."
command -v xcodebuild >/dev/null || fail "Xcode command-line tools are unavailable."
command -v codesign >/dev/null || fail "macOS codesign is unavailable."
command -v plutil >/dev/null || fail "macOS plutil is unavailable."
command -v ditto >/dev/null || fail "macOS ditto is unavailable."
command -v python3 >/dev/null || fail "Python 3 is required to validate the signed entitlements."

: "${NEXA_TEAM_ID:?Set your 10-character Apple Developer Team ID}"
: "${NEXA_BUNDLE_ID:?Set your unique iPhone bundle identifier}"
: "${NEXA_PHONE_APP_GROUP:?Set a provisioned iPhone App Group (group.*)}"
: "${NEXA_WATCH_APP_GROUP:?Set a provisioned Watch App Group (group.*)}"

[[ "$NEXA_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "Invalid Team ID syntax."
[[ "$NEXA_BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || fail "Invalid bundle identifier."
[[ "$NEXA_BUNDLE_ID" != com.example.* ]] || fail "Replace the example bundle identifier."
[[ "$NEXA_PHONE_APP_GROUP" =~ ^group\.[A-Za-z0-9][A-Za-z0-9.-]*$ ]] ||
  fail "Invalid iPhone App Group identifier."
[[ "$NEXA_WATCH_APP_GROUP" =~ ^group\.[A-Za-z0-9][A-Za-z0-9.-]*$ ]] ||
  fail "Invalid Watch App Group identifier."

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out="${NEXA_BUILD_DIR:-$root/build/Nexa-0.0.1}"
archive="$out/Nexa.xcarchive"
export_dir="$out/Export"
options="$out/ExportOptions.plist"
mkdir -p "$out"
# Leave an existing archive alone to avoid accidental destructive cleanup.
[[ ! -e "$archive" ]] || fail "Archive already exists: $archive. Use a new NEXA_BUILD_DIR."
[[ ! -e "$export_dir" ]] || fail "Export folder already exists: $export_dir. Use a new NEXA_BUILD_DIR."

cat > "$options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>debugging</string>
  <key>destination</key><string>export</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$NEXA_TEAM_ID</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF
plutil -lint "$options"

echo "Archiving Nexa and NexaWatch with owner-provisioned App Groups..."
xcodebuild \
  -project "$root/Nexa.xcodeproj" \
  -scheme Nexa \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$NEXA_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  NEXA_COMPANION_BUNDLE_IDENTIFIER="$NEXA_BUNDLE_ID" \
  NEXA_APP_GROUP_IDENTIFIER="$NEXA_PHONE_APP_GROUP" \
  NEXA_WATCH_APP_GROUP_IDENTIFIER="$NEXA_WATCH_APP_GROUP" \
  archive

app="$archive/Products/Applications/Nexa.app"
watch="$app/Watch/NexaWatch.app"
[[ -d "$app" && -d "$watch" ]] || fail "The archive does not include the embedded Watch app."
codesign --verify --deep --strict "$app" || fail "Signed iPhone/Watch bundle verification failed."

# Read entitlements from actual codesign signatures, not Info.plist alone.
validate_signed_pair() {
  local target_app="$1"
  local stage="$2"
  local target_watch="$target_app/Watch/NexaWatch.app"
  [[ -d "$target_app" && -d "$target_watch" ]] || fail "$stage: missing embedded Watch app."
  codesign --verify --strict "$target_app" || fail "$stage: invalid iPhone signature."
  codesign --verify --strict "$target_watch" || fail "$stage: invalid Watch signature."
  local phone_rights="$out/$stage-phone-entitlements.plist"
  local watch_rights="$out/$stage-watch-entitlements.plist"
  codesign --display --entitlements - --xml "$target_app" > "$phone_rights" ||
    fail "$stage: failed to read iPhone signature entitlements."
  codesign --display --entitlements - --xml "$target_watch" > "$watch_rights" ||
    fail "$stage: failed to read Watch signature entitlements."
  python3 "$root/Scripts/validate_signed_bundle.py" \
    --phone-info "$target_app/Info.plist" \
    --watch-info "$target_watch/Info.plist" \
    --phone-entitlements "$phone_rights" \
    --watch-entitlements "$watch_rights" \
    --phone-bundle "$NEXA_BUNDLE_ID" \
    --phone-group "$NEXA_PHONE_APP_GROUP" \
    --watch-group "$NEXA_WATCH_APP_GROUP" \
    --team "$NEXA_TEAM_ID" ||
      fail "$stage: signed entitlements or application identity mismatch."
}
validate_signed_pair "$app" archive

echo "Exporting owner-signed debugging IPA..."
xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportPath "$export_dir" \
  -exportOptionsPlist "$options" \
  -allowProvisioningUpdates

ipa="$(find "$export_dir" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "$ipa" && -s "$ipa" ]] || fail "A signed IPA was not produced."
unzip -Z1 "$ipa" | grep 'Payload/Nexa.app/Watch/NexaWatch.app/' >/dev/null ||
  fail "The exported IPA has no embedded Watch app."
verification="$out/ExportVerification"
[[ ! -e "$verification" ]] || fail "Export verification directory already exists."
mkdir -p "$verification"
ditto -x -k "$ipa" "$verification"
validate_signed_pair "$verification/Payload/Nexa.app" exported
echo "PASS: signed archive AND exported IPA include verified iPhone/Watch App Groups."
echo "IPA: $ipa"
echo "WARNING: archive and signing checks do not validate WQFiles, MobileGestalt writes, or Watch face changes on a real device."
