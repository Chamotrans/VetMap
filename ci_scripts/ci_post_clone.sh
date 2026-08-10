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
compatibility_binary="$semantic_directory/clinic-availability-manifest-compatibility"
feedback_binary="$semantic_directory/clinic-availability-feedback"
duplicate_binary="$semantic_directory/clinic-duplicate-matcher"
approval_operation_binary="$semantic_directory/clinic-approval-operation"
publication_binary="$semantic_directory/clinic-publication-policy"
chat_origin_binary="$semantic_directory/chat-origin"
chat_draft_binary="$semantic_directory/chat-draft-recovery"
clinic_favorites_binary="$semantic_directory/clinic-favorites"
location_permission_binary="$semantic_directory/location-permission"
community_auth_binary="$semantic_directory/community-auth-continuation"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicCoordinate.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/VetClinic.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicSearchFilter.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_availability_semantics_harness.swift" \
  -o "$semantic_binary"

"$semantic_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicCoordinate.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/VetClinic.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicSearchFilter.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_availability_manifest_compatibility_harness.swift" \
  -o "$compatibility_binary"

"$compatibility_binary" \
  "$CI_PRIMARY_REPOSITORY_PATH/catalog/hk_clinic_hours_v1.json" \
  "$CI_PRIMARY_REPOSITORY_PATH/catalog/hk_clinic_hours_v2.pending.json"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicCoordinate.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/VetClinic.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicAvailabilityFeedback.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_availability_feedback_harness.swift" \
  -o "$feedback_binary"

"$feedback_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicCoordinate.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/VetClinic.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicDuplicateMatcher.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_duplicate_matcher_harness.swift" \
  -o "$duplicate_binary"

"$duplicate_binary"

/usr/bin/xcrun swiftc \
  -D CLINIC_APPROVAL_OPERATION_HARNESS \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Services/ModerationStore.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_approval_operation_harness.swift" \
  -o "$approval_operation_binary"

"$approval_operation_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicCoordinate.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/VetClinic.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/ClinicPublicationPolicy.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_publication_policy_harness.swift" \
  -o "$publication_binary"

"$publication_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/Chat.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/chat_origin_harness.swift" \
  -o "$chat_origin_binary"

"$chat_origin_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/Chat.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/chat_draft_recovery_harness.swift" \
  -o "$chat_draft_binary"

"$chat_draft_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/UserProfile.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/clinic_favorites_harness.swift" \
  -o "$clinic_favorites_binary"

"$clinic_favorites_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Services/LocationService.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/location_permission_policy_harness.swift" \
  -o "$location_permission_binary"

"$location_permission_binary"

/usr/bin/xcrun swiftc \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/UserProfile.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/VetMap/Models/Quote.swift" \
  "$CI_PRIMARY_REPOSITORY_PATH/scripts/community_auth_continuation_harness.swift" \
  -o "$community_auth_binary"

"$community_auth_binary"
