#!/usr/bin/env bash
set -euo pipefail

# Build script for packaging Citadel.app into a distributable DMG

APP_NAME="Citadel"
VERSION="${1:-1.0.0}"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-macOS-arm64.dmg"
OUTPUT_DIR="dist"

echo "==> Building Citadel in release mode..."
swift build -c release --product CitadelApp

echo "==> Creating macOS App Bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/CitadelApp" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Embed App Icon
if [ -f "branding/AppIcon.icns" ]; then
    echo "==> Embedding AppIcon.icns into app bundle..."
    cp "branding/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

# Embed Info.plist
cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>sh.citadel.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Inject production secrets if present in environment
if [ -n "${CITADEL_GITHUB_CLIENT_ID:-}" ]; then
    echo "==> Injecting GitHub Client ID into app bundle..."
    cat <<EOF > "${APP_BUNDLE}/Contents/Resources/citadel-secrets.json"
{
  "github_client_id": "${CITADEL_GITHUB_CLIENT_ID}"
}
EOF
fi

echo "==> Ad-hoc codesigning app bundle..."
ENTITLEMENTS_FILE="${BUILD_DIR}/Citadel.entitlements"
cat <<EOF > "${ENTITLEMENTS_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# Perform ad-hoc codesign on bundle and binary
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}"
    echo "==> Verified ad-hoc signature:"
    codesign -dvv "${APP_BUNDLE}" 2>&1 | grep -E "Signature|Identifier|Format" || true
fi

echo "==> Generating DMG..."
mkdir -p "${OUTPUT_DIR}"
DMG_STAGING="${BUILD_DIR}/dmg_staging"
rm -rf "${DMG_STAGING}"
mkdir -p "${DMG_STAGING}"

cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov -format UDZO \
    "${OUTPUT_DIR}/${DMG_NAME}"

rm -rf "${DMG_STAGING}"
echo "==> Successfully created ${OUTPUT_DIR}/${DMG_NAME}"
