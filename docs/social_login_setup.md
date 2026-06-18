# Social Login Setup

Match A Man uses Supabase Auth OAuth for social login. Firebase Auth, Firebase
packages, push notifications, and provider-specific sign-in packages are not
part of this flow.

## Providers

- Google is configured in Supabase Dashboard.
- Facebook login is removed/disabled for launch and must not appear in the
  launch UI.
- Android Closed Testing uses email/password and Google login only.
- Social login buttons are icon-only. Android Closed Testing shows the Google
  icon only; Apple is hidden on Android and no Apple coming-soon copy is shown.
- Apple sign-in is platform-gated for iOS/macOS and should only be shown when
  the app has a real Apple OAuth callback wired and Apple Developer/Supabase
  setup is complete.
- Email/password auth remains enabled.
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
- Facebook login is disabled for launch; do not add it back to the UI unless a
  later launch decision explicitly re-enables it.
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

- In Google developer dashboard, use the Supabase provider callback URL:

```text
https://<project-ref>.supabase.co/auth/v1/callback
```

## Web Test Command

Run local web on port 3000 so OAuth can return to the configured redirect URL:

```bash
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_URL='...' \
  --dart-define=SUPABASE_ANON_KEY='...'
```

Do not commit real Supabase keys, Google secrets, or Apple credentials.

## App Notes

- Android is configured for `matchaman://login-callback/`.
- iOS is configured for the `matchaman` URL scheme.
- Web OAuth returns to `/auth/callback`; Supabase Flutter handles the incoming
  OAuth callback and session recovery before the app routes to setup or Events.
- Flutter Web uses path URL routing so `http://localhost:3000/auth/callback`
  is handled as an app route instead of a hash route.
- Google signup creates a safe lowercase username and a 4-digit
  profile tag automatically when the profile is missing or incomplete.
  Username generation tries the email local part first, then provider display
  name, then `user_<short uuid>`, with a suffix retry for collisions.
- Email signup/profile completion also gets a generated 4-digit profile tag.
  Public handles display as `username#0000`; users type only `username`, never
  the `#0000` tag.
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
- When profile completion starts from an event action, the app uses a safe
  internal `returnTo` path to return to the event detail or create flow after
  save.
- Apple sign-in is platform-gated to iOS/macOS and must remain hidden on
  Android closed testing builds.
- Email from social providers must not be exposed publicly.
- Google login remains enabled for launch.
- Facebook login is removed/disabled for launch.
- iOS App Store review may require Sign in with Apple or an equivalent
  privacy-preserving login before production submission. The app-side OAuth
  method can use Supabase Apple OAuth after the manual setup below is complete.
- Automated tests cover redirect helper and onboarding rules, but they cannot
  complete real Google browser OAuth, provider dashboard setup, captcha, or 2FA.
  Manual provider testing is still required.

## Apple iOS Setup Checklist

- Enroll in the Apple Developer Program.
- Enable the Sign in with Apple capability for the iOS Bundle ID.
- Configure the Supabase Auth Apple provider.
- Add the required redirect/callback settings in Apple and Supabase.
- Validate Apple sign-in on a real iOS device or TestFlight build.
