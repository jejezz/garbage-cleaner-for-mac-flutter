#!/usr/bin/env bash
# Build a distributable MacBroom.dmg (+ .zip) into dist/.
#
#   ./scripts/release.sh                      # ad-hoc signed (personal / testing)
#   SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE=macbroom ./scripts/release.sh   # signed + notarized + stapled
#
# One-time setup for notarization (needs an Apple Developer Program account):
#   xcrun notarytool store-credentials macbroom \
#       --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="MacBroom"
VERSION=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
BUILD_DIR="build/macos/Build/Products/Release"
APP="$BUILD_DIR/$APP_NAME.app"
DIST="dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ZIP="$DIST/$APP_NAME-$VERSION.zip"
ENTITLEMENTS="macos/Runner/Release.entitlements"

step() { printf '\n\033[1;35m▶ %s\033[0m\n' "$*"; }

step "Build $APP_NAME $VERSION (release)"
flutter build macos --release

step "Sign"
if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  # --options runtime = Hardened Runtime, required by notarization.
  # --deep signs the bundled Flutter/plugin frameworks with the same identity.
  codesign --force --deep --timestamp --options runtime \
           --entitlements "$ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$APP"
else
  echo "SIGNING_IDENTITY not set → ad-hoc signature (Gatekeeper will warn on first launch)."
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"

step "Package"
rm -rf "$DIST" && mkdir -p "$DIST"
STAGING=$(mktemp -d)
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
rm -rf "$STAGING"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  step "Notarize (this can take a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler staple "$APP"
  spctl --assess --type open --context context:primary-signature -v "$DMG"
fi

step "Done"
ls -lh "$DIST"
shasum -a 256 "$DMG" "$ZIP"
