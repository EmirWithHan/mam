# Android Device QA

Date: 2026-06-04

## Status

Use this document to record real-device Android QA for the internal MVP build.
iOS no-codesign cloud build has already passed; iOS simulator/device QA still
needs a Mac later.

## APK Build Command

Run from the project root:

```bash
flutter build apk --debug
```

Optional release sanity build, using the existing config only:

```bash
flutter build apk --release
```

Do not add keystores, signing configs, secrets, Firebase, or push setup for
this internal QA pass.

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
