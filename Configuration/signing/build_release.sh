#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="$ROOT_DIR/InterestingNotch.xcodeproj"
ARCHIVE_DIR="${ARCHIVE_DIR:-$ROOT_DIR/Release/InterestingNotch.xcarchive}"
APP_DIR="$ARCHIVE_DIR/Products/Applications/InterestingNotch.app"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/Release/InterestingNotch.dmg}"
ZIP_PATH="${ZIP_PATH:-${TMPDIR:-/tmp}/InterestingNotch-notarization.zip}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"

: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your Apple Developer Team ID}"
: "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to your stored notarytool keychain profile}"

mkdir -p "$ROOT_DIR/Release"
rm -rf "$ARCHIVE_DIR" "$ZIP_PATH" "$DMG_PATH"

security find-identity -v -p codesigning | grep -Fq 'Developer ID Application' || {
  echo "Developer ID Application certificate is not installed in the login keychain." >&2
  exit 1
}

codesign_runtime() {
  local target="$1"
  if [[ -e "$target" ]]; then
    codesign --force --options runtime --sign "$SIGNING_IDENTITY" "$target"
  fi
}

xcodebuild archive \
  -project "$PROJECT" \
  -scheme InterestingNotch \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  | tee "$ROOT_DIR/Release/archive.log"

test -d "$APP_DIR"

codesign_runtime "$APP_DIR/Contents/Frameworks/Lottie.framework"
codesign_runtime "$APP_DIR/Contents/Frameworks/MediaRemoteAdapter.framework"
codesign_runtime "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign_runtime "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc"
codesign_runtime "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc"
codesign_runtime "$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
codesign_runtime "$APP_DIR/Contents/XPCServices/InterestingNotchXPCHelper.xpc"
codesign_runtime "$APP_DIR/Contents/Resources/MediaRemoteAdapterTestClient"
codesign_runtime "$APP_DIR/Contents/Frameworks/Sparkle.framework"
codesign_runtime "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
spctl --assess --type execute --verbose=4 "$APP_DIR" || true

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"

"$ROOT_DIR/Configuration/dmg/create_dmg.sh" "$APP_DIR" "$DMG_PATH" "InterestingNotch"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "Signed release ready: $DMG_PATH"
