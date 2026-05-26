# Social Login Setup

Match A Man uses Supabase Auth OAuth for social login. Firebase Auth, Firebase
packages, push notifications, and provider-specific sign-in packages are not
part of this flow.

## Providers

- Google is configured in Supabase Dashboard.
- Facebook is configured in Supabase Dashboard.
- Apple is postponed until the Apple Developer Program is active. The app shows
  an Apple button as disabled/Yakında and does not start Apple OAuth.
- Email confirmation changes signup behavior: when confirmation is enabled,
  Supabase may create the user without returning an active session, so the app
  asks the user to check their inbox instead of creating a fake session.

## Redirect URLs

Mobile deep link callback:

```text
matchaman://login-callback/
```

Web development callback:

```text
http://localhost:3000/auth/callback
```

Do not hardcode production domains in app code. Add production web URLs in the
Supabase Dashboard per environment.

## Supabase Dashboard

- Open Authentication -> Providers -> Google and confirm it is enabled.
- Open Authentication -> Providers -> Facebook and confirm it is enabled.
- Add the provider Client ID and Client Secret values in Supabase only.
- Open Authentication -> URL Configuration.
- Add allowed redirect URLs for mobile, local web, and production web:

```text
matchaman://login-callback/
matchaman://**
http://localhost:3000
http://localhost:3000/**
http://localhost:3000/auth/callback
https://<production-domain>
```

- In Google and Facebook developer dashboards, use the Supabase provider
  callback URL:

```text
https://exzwwvjfudevpycpypkf.supabase.co/auth/v1/callback
```

## Web Test Command

Run local web on port 3000 so OAuth can return to the configured redirect URL:

```bash
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL='...' \
  --dart-define=SUPABASE_ANON_KEY='...'
```

Do not commit real Supabase keys, Google secrets, Facebook secrets, or Apple
credentials.

## App Notes

- Android is configured for `matchaman://login-callback/`.
- iOS is configured for the `matchaman` URL scheme.
- Web OAuth returns to `/auth/callback`; Supabase Flutter handles the incoming
  OAuth callback and session recovery before the app routes to setup or Events.
- Flutter Web uses path URL routing so `http://localhost:3000/auth/callback`
  is handled as an app route instead of a hash route.
- Google and Facebook signup create a safe lowercase username automatically
  when the profile is missing or incomplete. Generation tries the email local
  part first, then provider display name, then `user_<short uuid>`, with a
  suffix retry for collisions.
- If the OAuth session succeeds but the profile row is missing, the app creates
  the profile during first authenticated bootstrap instead of sending the user
  back to login.
- The database profile-completion constraint is aligned with the app: core
  profiles require username and name/full_name; birth date, gender, city,
  district, phone, bio, and avatar remain optional for general access.
- Generated and manually entered usernames are stored lowercase. Uppercase input
  is accepted in the app, normalized before save, and must resolve to letters,
  numbers, or `_`.
- Social metadata may prefill name and avatar only.
- Missing optional fields do not block Home, Feed, Events browsing, Profile,
  Follow, or Notifications. Creating or joining events can still require city,
  district, and birth date.
- Apple remains postponed and the app does not start Apple OAuth.
- Email from social providers must not be exposed publicly.
- Automated tests cover redirect helper and onboarding rules, but they cannot
  complete real Google/Facebook browser OAuth, provider dashboard setup,
  captcha, or 2FA. Manual provider testing is still required.
