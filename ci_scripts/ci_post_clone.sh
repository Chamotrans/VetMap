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

semantic_directory=$(mktemp -d "${TMPDIR:-/tmp}/vetmap-availability-semantics.XXXXXX")
trap 'rm -rf "$semantic_directory"' EXIT HUP INT TERM
semantic_binary="$semantic_directory/clinic-availability-semantics"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicCoordinate.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/VetClinic.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicSearchFilter.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_availability_semantics_harness.swift" \
  -o "$semantic_binary"

"$semantic_binary"
