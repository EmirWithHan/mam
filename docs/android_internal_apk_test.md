# Android Internal APK Test

Date: 2026-06-04

## Build Command

Run from the project root on Windows:

```bash
flutter build apk --debug
```

Optional release sanity build, using the existing project config only:

```bash
flutter build apk --release
```

Do not create a signing config, commit keystore files, or add secrets for this
internal APK pass.

## APK Location

Debug APK:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Release APK, if built:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The release APK currently uses the existing debug signing config and is only a
build sanity artifact. It is not a Play Store submission artifact.

## Install On Android Device

1. Enable developer options and USB debugging on the Android test device.
2. Connect the device by USB.
3. Install with:

```bash
flutter install --debug
```

Or copy `app-debug.apk` to the device and install it manually after allowing
install from unknown sources for the chosen file manager/browser.

## Required Test Accounts

Prepare these accounts in the internal Supabase test project. Do not hardcode
or share passwords/secrets in this repo.

- Normal user A: completed public profile.
- Normal user B: completed public profile.
- Private user: completed private profile.
- Business applicant: normal user with no active business account.
- Approved business user: active approved business account.
- Admin user: user present in `admin_users`.

## Smoke Test Steps

- Login/register.
- Feed opens.
- Create post with a gallery image.
- Events open.
- Create event.
- Join event.
- Host approve/reject participant.
- Username search.
- Add friend/follow.
- Business application.
- Admin approve/reject.
- Business delete.
- Feedback form.
- Logout and session restore.

For every flow, check that there is no white screen, route loop, raw
`PostgrestException`, SQLSTATE/PGRST text, clipped primary button, or stuck
loading state.

## Android Manifest Checklist

- App label is `Match A Man`.
- `INTERNET` permission exists.
- Location permissions exist because event creation can use current location.
- Camera permission is not declared.
- Photo/media permission is not declared in the main manifest.
- No debug/test activity is exposed in the main manifest.

## Known Limitations

- Push notifications are not implemented.
- Apple login is postponed.
- Real OTP phone verification is postponed.
- Payments are postponed.
- Production Android signing is not configured for store submission.
- Internal testers should use the prepared Supabase test environment only.
- iOS will be tested later on Mac with Xcode.

## Reporting Format

- Device model:
- Android version:
- APK path/build:
- Account used:
- Flow tested:
- Expected:
- Actual:
- Screenshot/video:
- Time of issue:
