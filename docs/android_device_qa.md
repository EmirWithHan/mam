# Android Device QA

Date: 2026-06-06

## Status

Use this document to record real-device Android QA for the internal MVP build.
iOS no-codesign cloud build has already passed; iOS simulator/device QA still
needs a Mac later.

## 2026-06-05 Real Device Blocker Pass

The APK now opens on a real Android phone when built with the required
Supabase dart-defines.

Blockers found after install:

- Some authenticated pages showed generic `Bir seyler ters gitti` copy.
- Some normal-user flows showed `Bu islem icin yetkin yok`.
- Some narrow Android screens showed yellow/black overflow stripes.

Fixed areas:

- Events list and Event detail public read paths.
- Host-only participant attendance query no longer runs for non-host viewers.
- Business application and business account normal-user grants/policies.
- Username search, public profile/feed RPC execute grants.
- Admin/business application cards with long names, IDs, phone, address, and URL.
- Event/business chips with long labels.
- Android back callback manifest flag.

No Firebase or push notifications were added. No product features were added.

## 2026-06-06 Remaining Blocker Sweep

Focused sweep after the Events RLS recursion and Events header scroll fixes.

Pages checked in code:

- Home/feed
- Events
- Event detail
- Create event
- Social
- Profile/public profile
- Settings
- Notifications
- Username search
- Feedback
- Business application/settings
- Admin applications/feedback, when admin route is accessible

Fixes verified or added in this pass:

- Events RLS recursion is covered by migration
  `20260606090000_fix_events_rls_infinite_recursion.sql`.
- Events header/search/create controls are part of the scrollable list and no
  longer stay pinned above event cards.
- Realtime subscription failures now use sanitized debug logging through
  `logSupabaseDebug` instead of printing raw error objects.
- Notification list/count/actions log developer code/message only and keep
  friendly Turkish UI messages.
- Feedback submit/admin feedback load logs developer code/message only before
  returning friendly Turkish copy.
- Business account/application reads and admin application list RPC log
  developer code/message only.
- Auth routing treats `AuthStatus.error` as unauthenticated for protected routes;
  a new login attempt resets auth state to loading, so logout/login should not
  get stuck in an `auth=error` route loop.

No additional migration was added in this sweep.
No Firebase or push notifications were added. No product features were added.

The Android white screen seen on real devices was caused by building/installing
an APK without the required Supabase dart-defines. Build the APK once with the
dart-defines below; the same built APK can then be installed on multiple Android
phones for internal testing.

## Run On Android Phone

With a USB-connected Android phone, replace `DEVICE_ID` and the placeholders
with the internal test project public values:

```powershell
flutter run -d DEVICE_ID ^
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Do not use the Supabase `service_role` key in the app, docs, build commands, or
client code.

## APK Build Command

Run from the project root:

```powershell
flutter build apk --debug ^
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Optional release sanity build, using the existing config only:

```powershell
flutter build apk --release ^
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL ^
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Do not add keystores, signing configs, secrets, Firebase, or push setup for
this internal QA pass.

If the public Supabase URL/anon key are omitted, the app now shows a friendly
startup failure screen instead of a blank white screen.

The Supabase publishable/anon key is expected to be included in mobile app
builds. Security must come from RLS policies, least-privilege grants, and never
shipping service-role or other secret keys in the client.

Developers may create local private scripts for convenience:

```text
scripts/build_debug_apk.local.ps1
scripts/build_release_aab.local.ps1
```

Those local scripts are ignored by Git. Keep real Supabase values out of
committed files.

Capture Flutter logs on Windows:

```bash
adb logcat | findstr flutter
```

If the app shows `Uygulama başlatılamadı`, rebuild with the required
`--dart-define` values and confirm the device has network access.

## APK Path

Debug APK:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Release sanity APK, if built:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Install APK On Android

Option A, USB install:

```bash
flutter install --debug
```

Option B, manual install:

1. Copy `build/app/outputs/flutter-apk/app-debug.apk` to the device.
2. Allow install from unknown sources for the chosen file manager/browser.
3. Tap the APK and install.
4. Open `Match A Man`.

## Required Test Accounts

Prepare these accounts in the internal Supabase test project. Do not write
passwords, tokens, service keys, OAuth secrets, or database credentials here.

- Normal user A: completed public profile.
- Normal user B: completed public profile.
- Private user: completed profile with private account enabled.
- Host user: owns a test event.
- Business applicant: normal user with no active business account.
- Approved business user: active approved business account.
- Admin user: present in `admin_users`.

## Test Device Info

- Tester:
- Date/time:
- APK path/build:
- Device model:
- Android version:
- Screen size/resolution:
- Network:
- Supabase project/environment:
- Accounts used:

## MVP Flow Checklist

- [ ] First open shows splash/auth without white screen.
- [ ] Register with email.
- [ ] Login with email.
- [ ] Session restore after closing/reopening app.
- [ ] Logout.
- [ ] Profile completion.
- [ ] Feed load.
- [ ] Create post with gallery image.
- [ ] Events list opens.
- [ ] Create event.
- [ ] Event detail opens.
- [ ] Join request.
- [ ] Host approve request.
- [ ] Host reject request.
- [ ] Leave event.
- [ ] Username search.
- [ ] Add friend/follow public user.
- [ ] Private follow request.
- [ ] Own profile view.
- [ ] Public profile view.
- [ ] Settings opens.
- [ ] Business application.
- [ ] Admin approve application.
- [ ] Admin reject application.
- [ ] Business delete.
- [ ] Feedback form submit.

## Remaining Manual Blocker Checklist

- [ ] Build/install APK with the dart-define command in this document.
- [ ] Logout returns to auth screen.
- [ ] Login again after logout works with the same account.
- [ ] Failed login shows friendly copy, then successful login recovers.
- [ ] No `auth=error` route loop after back/close/reopen.
- [ ] Login as normal user and open Home, Events, Social, Profile, Settings.
- [ ] Login as approved business user and open Home, Events, Social, Profile,
      Settings.
- [ ] Confirm normal user can search usernames and open public profiles.
- [ ] Confirm normal user can view public feed/event data.
- [ ] Confirm normal user can submit business application and feedback.
- [ ] Confirm non-admin sees admin-only copy only on admin applications screen.
- [ ] Confirm normal user does not see raw SQL, PGRST, SQLSTATE, or stack trace.
- [ ] Confirm normal user does not see `Bu islem icin yetkin yok` on Events,
      Profile, Settings, Social, Notifications, Username search, or Feedback.
- [ ] Confirm event detail opens for host, participant, and unrelated normal user.
- [ ] Confirm create event form works for a completed normal profile.
- [ ] Confirm comments load and submit on visible posts.
- [ ] Confirm Events title/search/filter/create area scrolls away with cards.
- [ ] Confirm no yellow/black overflow on a small Android device.

## Android Layout And Device Checks

- [ ] Small screen device tested if available.
- [ ] Keyboard open on login/register/profile/create post/create event/business/feedback.
- [ ] Submit buttons remain visible or reachable by scrolling.
- [ ] Bottom navigation works and is not clipped.
- [ ] Android back button behavior is sensible from core screens.
- [ ] Image upload opens gallery and handles cancel.
- [ ] Location button requests permission only when tapped.
- [ ] Location denied/disabled shows friendly message.
- [ ] No white screen.
- [ ] No yellow/black overflow.
- [ ] No infinite width exception.
- [ ] No raw `PostgrestException`, SQLSTATE, PGRST, or stack trace shown.
- [ ] Loading buttons prevent confusing duplicate submit.

## Known Issues

- Real production Android signing is not configured.
- Push notifications are not implemented.
- Real OTP phone verification is postponed.
- Payments are postponed.
- iOS device/simulator QA still needs Mac/Xcode.
- Live Supabase RLS/RPC/storage behavior must be verified with real test accounts
  before closed beta.

## Failure Report Template

- Device:
- Account:
- Flow:
- Steps:
- Expected:
- Actual:
- Screenshot/video:
- Raw error text, if any:
- Time:
- Severity:
