#!/bin/bash
set -e

echo "🏥 VetMap — Archive & Export for TestFlight"
echo "============================================"

PROJECT="VetMap.xcodeproj"
SCHEME="VetMap"
ARCHIVE_PATH="./build/VetMap.xcarchive"
EXPORT_PATH="./build/VetMap-Export"
EXPORT_PLIST="./scripts/ExportOptions.plist"

# 1. Clean
echo "1/4 Cleaning..."
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -quiet

# 2. Archive
echo "2/4 Archiving..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=iOS' \
    CODE_SIGN_STYLE=Manual

# 3. Export
echo "3/4 Exporting IPA..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST"

# 4. Upload to TestFlight
echo "4/4 Uploading to TestFlight..."
xcrun altool --upload-app \
    -f "$EXPORT_PATH/VetMap.ipa" \
    -t ios \
    --apiKey "$APPSTORE_API_KEY_ID" \
    --apiIssuer "$APPSTORE_ISSUER_ID"

echo "✅ Done! Check TestFlight in App Store Connect."
