#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RELEASE_DIR="${RELEASE_DIR:-$ROOT_DIR/Release}"
DMG_PATH="${DMG_PATH:-$RELEASE_DIR/InterestingNotch.dmg}"
APPCAST_PATH="${APPCAST_PATH:-$ROOT_DIR/appcast.xml}"
UPDATER_APPCAST_PATH="${UPDATER_APPCAST_PATH:-$ROOT_DIR/updater/appcast.xml}"
RELEASE_NOTES_HTML="${RELEASE_NOTES_HTML:-$RELEASE_DIR/InterestingNotch.html}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/interestingnotch-sparkle-derived}"
SPARKLE_SRC_DIR="${SPARKLE_SRC_DIR:-${TMPDIR:-/tmp}/Sparkle}"
SPARKLE_REPO_URL="${SPARKLE_REPO_URL:-https://github.com/sparkle-project/Sparkle}"
RELEASE_REPOSITORY="${RELEASE_REPOSITORY:-nodescraper/interestingnotch}"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [release-notes-markdown-file]" >&2
  exit 1
fi

RELEASE_NOTES_FILE="${2:-}"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found at $DMG_PATH. Run Configuration/signing/build_release.sh first." >&2
  exit 1
fi

SPARKLE_PRIVATE_KEY_CONTENT="${SPARKLE_PRIVATE_KEY:-}"
if [[ -z "$SPARKLE_PRIVATE_KEY_CONTENT" && -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  if [[ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    echo "SPARKLE_PRIVATE_KEY_FILE does not exist: $SPARKLE_PRIVATE_KEY_FILE" >&2
    exit 1
  fi
  SPARKLE_PRIVATE_KEY_CONTENT="$(<"$SPARKLE_PRIVATE_KEY_FILE")"
fi

if [[ -z "$SPARKLE_PRIVATE_KEY_CONTENT" ]]; then
  echo "Set SPARKLE_PRIVATE_KEY or SPARKLE_PRIVATE_KEY_FILE before publishing the appcast." >&2
  exit 1
fi

if [[ -n "$RELEASE_NOTES_FILE" ]]; then
  if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
    echo "Release notes file not found: $RELEASE_NOTES_FILE" >&2
    exit 1
  fi
  escaped_notes="$(python3 - "$RELEASE_NOTES_FILE" <<'PY'
import html
import pathlib
import sys

text = pathlib.Path(sys.argv[1]).read_text()
print("<html><body><pre>" + html.escape(text) + "</pre></body></html>")
PY
)"
  printf '%s\n' "$escaped_notes" > "$RELEASE_NOTES_HTML"
else
  cat > "$RELEASE_NOTES_HTML" <<EOF
<html>
  <body>
    <h1>InterestingNotch $VERSION</h1>
    <p>See the GitHub release for details.</p>
  </body>
</html>
EOF
fi

SPARKLE_METADATA_PATH="$ROOT_DIR/InterestingNotch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
IFS=$'\t' read -r SPARKLE_VERSION SPARKLE_REVISION <<< "$(python3 - "$SPARKLE_METADATA_PATH" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
pins = data.get("pins", [])
sparkle = next((pin for pin in pins if pin.get("identity") == "sparkle"), None)
if sparkle is None:
    print("::error::No 'sparkle' pin found in Package.resolved", file=sys.stderr)
    sys.exit(1)

state = sparkle.get("state", {})
version = state.get("version")
revision = state.get("revision")
if not version or not revision:
    print("::error::Sparkle pin is missing version or revision", file=sys.stderr)
    sys.exit(1)

print(f"{version}\t{revision}")
PY
)"

GENERATE_APPCAST_BIN=""
if [[ -x "$DERIVED_DATA_PATH/Build/Products/Release/generate_appcast" ]]; then
  GENERATE_APPCAST_BIN="$DERIVED_DATA_PATH/Build/Products/Release/generate_appcast"
fi

if [[ -z "$GENERATE_APPCAST_BIN" ]]; then
  rm -rf "$SPARKLE_SRC_DIR"
  SPARKLE_TAG=""
  for candidate in "$SPARKLE_VERSION" "v$SPARKLE_VERSION"; do
    if git ls-remote --exit-code --tags "$SPARKLE_REPO_URL" "refs/tags/$candidate" >/dev/null; then
      SPARKLE_TAG="$candidate"
      break
    fi
  done

  if [[ -z "$SPARKLE_TAG" ]]; then
    echo "Could not find Sparkle tag $SPARKLE_VERSION or v$SPARKLE_VERSION" >&2
    exit 1
  fi

  git clone \
    --depth 1 \
    --branch "$SPARKLE_TAG" \
    --single-branch \
    "$SPARKLE_REPO_URL" \
    "$SPARKLE_SRC_DIR"

  ACTUAL_REVISION="$(git -C "$SPARKLE_SRC_DIR" rev-parse HEAD)"
  if [[ "$ACTUAL_REVISION" != "$SPARKLE_REVISION" ]]; then
    echo "Sparkle tag $SPARKLE_TAG resolved to $ACTUAL_REVISION, expected $SPARKLE_REVISION" >&2
    exit 1
  fi

  xcodebuild -project "$SPARKLE_SRC_DIR/Sparkle.xcodeproj" \
    -scheme generate_appcast \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build

  GENERATE_APPCAST_BIN="$DERIVED_DATA_PATH/Build/Products/Release/generate_appcast"
fi

if [[ ! -x "$GENERATE_APPCAST_BIN" ]]; then
  echo "generate_appcast was not built successfully." >&2
  exit 1
fi

mkdir -p "$(dirname "$UPDATER_APPCAST_PATH")"

printf '%s' "$SPARKLE_PRIVATE_KEY_CONTENT" | "$GENERATE_APPCAST_BIN" \
  --ed-key-file - \
  --link "https://github.com/$RELEASE_REPOSITORY/releases" \
  --download-url-prefix "https://github.com/$RELEASE_REPOSITORY/releases/download/v$VERSION/" \
  -o "$APPCAST_PATH" \
  "$RELEASE_DIR/"

cp "$APPCAST_PATH" "$UPDATER_APPCAST_PATH"

if ! grep -q "<item>" "$APPCAST_PATH"; then
  echo "Generated appcast contains no release items." >&2
  exit 1
fi

echo "Appcast updated:"
echo "  $APPCAST_PATH"
echo "  $UPDATER_APPCAST_PATH"
echo
echo "Next:"
echo "  git add appcast.xml updater/appcast.xml"
echo "  git commit -m \"Update appcast for v$VERSION\""
echo "  git push origin main"
