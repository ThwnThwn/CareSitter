# Google Sign-In setup

CareSitter uses Google only to obtain an OpenID Connect ID token. The customer
app sends that token to `POST /api/v1/auth/google/customer`; the backend verifies
its signature and audience, then issues the normal CareSitter access and refresh
tokens.

## 1. Google Cloud Console

Configure the OAuth consent screen, then create these OAuth 2.0 clients in the
same Google Cloud project:

- **Web application**: this is the shared server/audience client ID.
- **Android**: package name `vn.caresitter.customer` plus the SHA-1/SHA-256 of
  every debug/release signing certificate.
- **iOS**: bundle ID `vn.caresitter.customer`.

For the Web client, add exact authorized JavaScript origins, for example:

- `http://localhost:7357`
- `https://app.caresitter.vn`

Do not add a path or trailing slash to an origin.

## 2. Backend

The backend audience must be the **Web application client ID**:

```env
Google__ClientId=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Restart the API after changing this value.

## 3. Flutter build/run

The app loads its public OAuth configuration from `frontend/customer-app/.env`
at startup:

```env
GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=
```

With that file configured, a normal web run works without passing the client ID
on the command line:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357
```

The helper script remains available for local development:

```powershell
.\run-web.ps1
```

The launcher can synchronize `GOOGLE_WEB_CLIENT_ID` from the process environment
or `Google__ClientId` in `backend/.env`, and uses `http://localhost:7357` by
default. Register this exact origin in Google Cloud. Use `-Device web-server`
for an existing browser, or `-CheckOnly` to validate configuration without
starting Flutter.

Values passed with `--dart-define` override the matching values in `.env`. After
changing Google authentication configuration, stop and relaunch Flutter so the
Google web SDK is initialized once with the new values.

Web development should use a stable port that is registered in Google Cloud:

```powershell
flutter run -d chrome `
  --web-hostname localhost `
  --web-port 7357 `
  --dart-define=BASE_URL=http://localhost:5033/api/v1 `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Android uses the same Web client ID as its server client ID:

```powershell
flutter run -d android `
  --dart-define=BASE_URL=http://10.0.2.2:5033/api/v1 `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

For iOS, also pass its platform client ID:

```powershell
flutter run -d ios `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com `
  --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
```

iOS additionally requires the reversed iOS client ID in
`ios/Runner/Info.plist` under `CFBundleURLSchemes`, as required by the official
Google Sign-In iOS setup.

## 4. Expected behavior

- Android/iOS uses Google's native account chooser.
- Web uses the official Google Identity Services button and opens Google's
  account selection UI.
- CareSitter clears only the plugin's local account selection after exchanging
  the ID token. It does not sign the user out of their Google account.
- Google owns the chooser UI. With several browser accounts it normally shows
  a list like the reference image; with one eligible account Google may continue
  directly, and the app must not imitate or replace that screen.

If Google reports `clientConfigurationError`, verify the package/bundle ID,
signing SHA, Web client ID, and authorized origin first.
