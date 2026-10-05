#!/usr/bin/env bash
# Builds the release app and packages it as dist/PathVador-<version>.dmg.
#
# Usage:
#   scripts/make_dmg.sh                 # ad-hoc signed; fine on this Mac
#   DEVELOPER_ID="Developer ID Application: Name (TEAMID)" \
#   NOTARY_PROFILE=path_vador scripts/make_dmg.sh
#                                       # signed + notarized for other Macs
#
# NOTARY_PROFILE is a keychain profile created once with:
#   xcrun notarytool store-credentials path_vador --apple-id <id> --team-id <TEAMID>
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME=PathVador
APP="ui/build/macos/Build/Products/Release/${APP_NAME}.app"
VERSION=$(sed -n 's/^version: *\([^+]*\).*/\1/p' ui/pubspec.yaml)
DIST=dist
DMG="${DIST}/${APP_NAME}-${VERSION}.dmg"

echo "==> Building ${APP_NAME} ${VERSION} (release)"
make ui-macos MODE=release

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "==> Signing with ${DEVELOPER_ID}"
  # Inner code first, then the bundle; hardened runtime is required for
  # notarization. The entitlements are the ones the build already applied.
  codesign -d --entitlements :- "$APP" >/tmp/path_vador.entitlements 2>/dev/null
  sign() { codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" "$@"; }
  sign "$APP/Contents/Frameworks/libpathvador.dylib"
  sign "$APP/Contents/Helpers/path_vador"
  find "$APP/Contents/Frameworks" -maxdepth 1 -name '*.framework' -print0 |
    while IFS= read -r -d '' fw; do sign "$fw"; done
  sign --entitlements /tmp/path_vador.entitlements "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "==> Staging disk image contents"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating ${DMG}"
mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG" >/dev/null

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing (this can take a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

hdiutil verify "$DMG" >/dev/null
echo "==> Done: ${DMG} ($(du -h "$DMG" | cut -f1))"
