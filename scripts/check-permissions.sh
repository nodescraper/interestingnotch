#!/bin/zsh
set -euo pipefail

app_path="${1:-}"
if [[ -z "$app_path" || ! -d "$app_path" ]]; then
  print -u2 "Usage: $0 /path/to/InterestingNotch.app"
  exit 2
fi

info="$app_path/Contents/Info.plist"
helper="$app_path/Contents/XPCServices/InterestingNotchXPCHelper.xpc"

main_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info")
helper_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$helper/Contents/Info.plist")
helper_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$helper/Contents/Info.plist")

[[ "$main_id" == "com.nodescraper.interestingnotch" ]]
[[ "$helper_id" == "$main_id.InterestingNotchXPCHelper" ]]
[[ "$helper_name" == "InterestingNotch" ]]

for key in NSCameraUsageDescription NSMicrophoneUsageDescription NSBluetoothAlwaysUsageDescription NSCalendarsFullAccessUsageDescription NSRemindersFullAccessUsageDescription; do
  /usr/libexec/PlistBuddy -c "Print :$key" "$info" >/dev/null
done

entitlements=$(mktemp)
trap 'rm -f "$entitlements"' EXIT
codesign -d --entitlements :- "$app_path" 2>&1 \
  | awk 'found || /^<\?xml/ { found = 1; print }' >"$entitlements"
plutil -lint "$entitlements" >/dev/null

for key in com.apple.security.device.camera com.apple.security.device.audio-input com.apple.security.device.bluetooth com.apple.security.personal-information.calendars; do
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$entitlements")" == "true" ]]
done

codesign --verify --deep --strict --verbose=2 "$app_path"
print "Permission configuration OK: $app_path"
