#!/bin/bash
set -euo pipefail

APP_NAME="Ethernet Status Lite"
BUNDLE_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
DMG_DIR=".build/dmg"
DMG_PATH=".build/${APP_NAME}.dmg"

echo "Building..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${CONTENTS_DIR}/Resources"

cp .build/release/EthernetStatusLite "${MACOS_DIR}/EthernetStatusLite"
cp Info.plist "${CONTENTS_DIR}/Info.plist"
cp Resources/*.png "${CONTENTS_DIR}/Resources/"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "${CONTENTS_DIR}/Resources/"
fi

echo "Signing..."
codesign --force --sign - "${BUNDLE_DIR}"

echo "Creating DMG..."
rm -rf "${DMG_DIR}" "${DMG_PATH}"
mkdir -p "${DMG_DIR}"
cp -r "${BUNDLE_DIR}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_DIR}" -ov -format UDZO "${DMG_PATH}"
rm -rf "${DMG_DIR}"

echo ""
echo "Done:"
echo "  App:  ${BUNDLE_DIR}"
echo "  DMG:  ${DMG_PATH}"
echo ""
echo "To run now:"
echo "  open \"${BUNDLE_DIR}\""
