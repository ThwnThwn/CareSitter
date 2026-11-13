#!/bin/sh
set -eu
# Only real device builds have a native crash binary to symbolicate.
[ "${PLATFORM_NAME:-}" = "iphoneos" ] || exit 0
config="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
[ -f "$config" ] || { echo 'error: Missing bundled GoogleService-Info.plist.' >&2; exit 1; }
spm_root="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk"
# flutter run overrides BUILD_DIR to project/build/ios; OBJROOT still identifies DerivedData.
spm_object_root="${OBJROOT:-}"
spm_object_root="${spm_object_root%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk"
for sdk_root in "${CARESITTER_FIREBASE_IOS_SDK_PATH:-}" "$spm_object_root" "$spm_root"; do
  if [ -n "$sdk_root" ] && [ -f "$sdk_root/Crashlytics/run" ]; then
    exec /bin/sh "$sdk_root/Crashlytics/run"
  fi
done
if [ -n "${PODS_ROOT:-}" ] && [ -f "$PODS_ROOT/FirebaseCrashlytics/run" ]; then
  exec /bin/sh "$PODS_ROOT/FirebaseCrashlytics/run"
else
  echo 'error: Firebase Crashlytics symbol uploader not found. Resolve SwiftPM packages in Xcode.' >&2
  exit 1
fi
