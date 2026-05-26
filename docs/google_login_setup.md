# Google Login Setup

This app uses Supabase Auth OAuth for Google login. Do not add Firebase Auth,
Firebase packages, or a Google Sign-In package for this flow.

## App callback

Mobile callback scheme used by the app:

```text
matchaman://login-callback/
```

Web returns through the browser redirect handled by Supabase Flutter. Keep
development and production web URLs environment-specific in the Supabase
Dashboard instead of hardcoding them in the app.

## Google Cloud Console

- Create or select the Google Cloud project for Match A Man.
- Configure the OAuth consent screen if Google requires it.
- Create OAuth client credentials for the app.
- Add this authorized redirect URI, replacing `<project-ref>` with the
  Supabase project ref:

```text
https://<project-ref>.supabase.co/auth/v1/callback
```

- Copy the Google Client ID and Client Secret for Supabase.
- Do not commit client secrets or paste them into app source files.

## Supabase Dashboard

- Open Authentication -> Providers -> Google.
- Enable Google.
- Add the Google Client ID and Client Secret from Google Cloud Console.
- Open Authentication -> URL Configuration.
- Add allowed redirect URLs for every environment that should return to the
  app.

Recommended allowed redirect URLs:

```text
matchaman://login-callback/
http://localhost:<dev-port>/
http://localhost:<dev-port>/auth/login
https://<production-domain>/
https://<production-domain>/auth/login
```

Use the actual local port and production domain for the deployed web app.

## App redirects

- Android is configured with an intent filter for `matchaman://login-callback/`.
- iOS is configured with the `matchaman` URL scheme.
- Supabase Flutter handles the incoming OAuth callback and auth session
  recovery.
- Google metadata may prefill first name, last name, and avatar only. Username
  still follows Match A Man profile rules and must be completed in the app.
- Email from Google must not be shown publicly.
