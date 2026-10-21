# CareSitter Firebase Setup

## Caregiver App

Current identifiers to register in Firebase:

- Android package name: `vn.caresitter.caregiver`
- iOS bundle ID: `vn.caresitter.caregiver`

Naming convention:

- Firebase/native app identifiers use lowercase reverse-domain syntax: `vn.caresitter.<app>`
- Dart package names can still use snake_case, for example `caregiver_app`, because Dart requires that style.

Steps:

1. Open Firebase Console and create/select the CareSitter project.
2. Add an Android app with package name `vn.caresitter.caregiver`.
3. Download `google-services.json`.
4. Put it at `frontend/caregiver-app/android/app/google-services.json`.
5. Add an iOS app with bundle ID `vn.caresitter.caregiver`.
6. Download `GoogleService-Info.plist`.
7. Put it at `frontend/caregiver-app/ios/Runner/GoogleService-Info.plist`.
8. Run from `frontend/caregiver-app`: `flutter pub get`.
9. Test Android with `flutter run -d <device-id>`.

The app initializes Firebase only when native config files are present. Without those files, push notification setup is skipped and the demo app can still run.

Alternative with FlutterFire CLI:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios --android-package-name=vn.caresitter.caregiver --ios-bundle-id=vn.caresitter.caregiver
```

That command should replace `lib/firebase_options.dart` with real, non-secret Firebase app options.

## Backend Push Sender

The backend uses Firebase Admin SDK. For local development:

1. In Firebase Console, open Project settings.
2. Go to Service accounts.
3. Generate a new private key JSON.
4. Save it outside git, for example `C:\Users\ADMIN\secrets\caresitter-firebase-adminsdk.json`.
5. Copy `backend/.env.example` to `backend/.env` if needed.
6. Set:

```env
Firebase__ServiceAccountPath=C:\Users\ADMIN\secrets\caresitter-firebase-adminsdk.json
Firebase__ServiceAccountJson=
Firebase__UseApplicationDefaultCredentials=false
```

Do not commit Firebase config or service account files. The root `.gitignore` already ignores the normal Firebase config file paths and service account JSON patterns.
