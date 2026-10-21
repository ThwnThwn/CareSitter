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

For the Web client, add these exact **Authorized redirect URIs** (replace the
production API domain with yours):

- `http://localhost:5033/api/v1/auth/google/customer/web/callback`
- `https://api.caresitter.vn/api/v1/auth/google/customer/web/callback`

The custom web button uses backend OAuth, not the GIS rendered button. JavaScript
origins alone are not sufficient. If retaining GIS elsewhere, keep its origins:

- `http://localhost:7357`
- `https://app.caresitter.vn`

Do not add a path or trailing slash to an origin.

## 2. Backend

The backend audience must be the **Web application client ID**:

```env
Google__ClientId=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
Google__ClientSecret=YOUR_WEB_CLIENT_SECRET
Google__Web__RedirectUri=http://localhost:5033/api/v1/auth/google/customer/web/callback
```

Set these in `backend/.env` locally or the backend secret manager in deployment.
**Never put the client secret in Flutter `.env`, assets, or dart-define.** Restart
the API after changes. Without all three values, web sign-in shows a configuration
error; native Google login remains available.

Outside Development, use an HTTPS callback and add the exact frontend origin to
`Cors__AllowedOrigins__N`, e.g. `https://app.caresitter.vn`. Only Development allows
arbitrary loopback ports. `BASE_URL` must point to the same public backend origin
as the callback. Avoid mixing `localhost` and `127.0.0.1`.

The backend validates OIDC state, correlation cookie, nonce and signed ID token,
with PKCE. Its callback sends the Google ID token only to the initiating frontend
origin via `postMessage`; tokens are never placed in the redirect URL. Flutter
checks sender origin, popup window and request ID before using the existing
customer login endpoint. The API does not create an external Google session.

## 3. Flutter build/run

The app loads its public OAuth configuration from `frontend/customer-app/.env`
at startup:

```env
GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=
```

Those public client IDs are used by Android/iOS. Web uses the backend's OAuth
configuration and `BASE_URL`; it does not initialize the Google web SDK:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 7357
```

The helper script remains available for local development:

```powershell
.\run-web.ps1
```

The launcher can synchronize `GOOGLE_WEB_CLIENT_ID` from the process environment
or `Google__ClientId` in `backend/.env`, and uses `http://localhost:7357` by
default. Use `-Device web-server`
for an existing browser, or `-CheckOnly` to validate configuration without
starting Flutter.

Values passed with `--dart-define` override the matching values in `.env`. After
changing Flutter build configuration, stop and relaunch Flutter. Backend OAuth
secret changes require restarting the API, not rebuilding Flutter.

Example web development command:

```powershell
flutter run -d chrome `
  --web-hostname localhost `
  --web-port 7357 `
  --dart-define=BASE_URL=http://localhost:5033/api/v1
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
- Web uses the same custom icon-only outlined button as Apple. It opens a popup
  to the backend, which redirects to Google's account chooser (`prompt=select_account`).
- Closing the popup cancels silently. A blocked popup displays instructions to
  allow it. Authentication expires after five minutes.
- CareSitter clears only the plugin's local account selection after exchanging
  the ID token. It does not sign the user out of their Google account.
- Google owns the chooser UI. With several browser accounts it normally shows
  a list like the reference image; with one eligible account Google may continue
  directly, and the app must not imitate or replace that screen.

If Google reports `redirect_uri_mismatch`, compare the exact Console redirect URI
with `Google__Web__RedirectUri` (scheme, host, port and path). If the popup cannot
return, check popup permissions and ensure the frontend/reverse proxy does not
set `Cross-Origin-Opener-Policy: same-origin`; use `same-origin-allow-popups` when
an opener policy is needed. Do not log OAuth callback query strings or bodies.

For native `clientConfigurationError`, verify package/bundle ID, signing SHA,
and Web client ID. The Apple action remains unchanged by this Google integration.
