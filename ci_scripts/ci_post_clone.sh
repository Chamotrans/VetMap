#!/bin/sh
set -eu

umask 077

: "${CI_PRIMARY_REPOSITORY_PATH:?Missing Xcode Cloud repository path}"
: "${GOOGLE_SERVICE_INFO_PLIST_BASE64:?Missing Firebase config secret}"

destination="$CI_PRIMARY_REPOSITORY_PATH/VetMap/GoogleService-Info.plist"

printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" \
  | /usr/bin/base64 -D > "$destination"

/usr/bin/plutil -lint "$destination"

bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$destination")
test "$bundle_id" = "com.vetmap.app"

echo "Firebase configuration installed for the VetMap Xcode Cloud build."
