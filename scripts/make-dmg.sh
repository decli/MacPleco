#!/bin/bash
# Packages dist/MacPleco.app into a distributable disk image and zip.
#
#   ./scripts/make-dmg.sh [version]
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="MacPleco"
VERSION="${1:-0.0.0-dev}"
DIST="dist"
APP="$DIST/$APP_NAME.app"
STAGE="$DIST/dmg-stage"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ZIP="$DIST/$APP_NAME-$VERSION.zip"

[ -d "$APP" ] || { echo "!! $APP not found; run scripts/build-app.sh first" >&2; exit 1; }

echo "==> Staging disk image contents"
rm -rf "$STAGE" "$DMG" "$ZIP"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp scripts/dmg-readme.txt "$STAGE/READ ME FIRST.txt"

echo "==> Creating $DMG"
hdiutil create \
	-volname "$APP_NAME" \
	-srcfolder "$STAGE" \
	-ov -format UDZO \
	"$DMG"

echo "==> Creating $ZIP"
# ditto preserves the symlinks and extended attributes inside the bundle, which
# a plain `zip` would flatten and break the code signature.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Artifacts"
ls -lh "$DMG" "$ZIP"
