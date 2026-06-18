# Play Closed Test Signed AAB Runbook

## Purpose

This runbook explains how to build the signed Android App Bundle for Google Play
closed testing. Play Console upload should use a signed release AAB, not a debug
APK.

## Local-Only Files Required

Create these files only on the local build machine:

```text
android/key.properties
android/app/upload-keystore.jks
```

Do not commit these files.

## Generate Upload Keystore

Run from the project root and choose strong passwords:

```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back up the keystore and passwords securely. Losing the upload key can block or
delay future Play Console releases.

## Local Key Properties Template

Create `android/key.properties` locally:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

The committed safe template is `android/key.properties.example`.

## Build Signed AAB

Use real Supabase values only in your local terminal or secure CI secrets:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Do Not Commit

- `build/app/outputs/bundle/release/app-release.aab`
- `android/app/upload-keystore.jks`
- `android/key.properties`
- signing passwords
- real dart-defines
- real Supabase URL/key

## Local Verification After Build

- Confirm `build/app/outputs/bundle/release/app-release.aab` exists.
- Confirm `pubspec.yaml` version maps to the intended `versionName` and
  `versionCode`.
- Confirm app label is `Match A Man`.
- Confirm app icon is the Match A Man icon, not the Flutter logo.
- Confirm the build is release mode and has no debug banner.
- Confirm debug APK testing still works separately for manual install testing.

## Current Signing Setup Status

- Release signing reads local `android/key.properties`.
- `android/key.properties` is ignored.
- `android/app/upload-keystore.jks` is ignored.
- Release builds fail when signing files are missing instead of silently using
  debug signing.
- Debug builds do not require release signing files.
