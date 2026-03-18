#!/bin/bash
set -e

APP_NAME="tranfEasy"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app/Contents"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_DIR}/MacOS"
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_DIR}/Info.plist"

echo "Done! ${APP_NAME}.app created."
echo "You can move it to ~/Applications or /Applications."
