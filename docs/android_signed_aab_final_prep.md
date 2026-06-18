# Android Signed AAB Final Prep

## Purpose

This document explains how to build the signed Android App Bundle for Play Store
closed testing.

## Local Files Not In Git

These files must exist locally on the build machine and must not be committed:

```text
android/key.properties
android/app/upload-keystore.jks
```

## Generate Upload Keystore

Run from the project root and choose strong passwords:

```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back up the keystore and passwords securely. If the upload key is lost, Play
Console releases can be blocked until key recovery is completed.

## Local `android/key.properties`

Create `android/key.properties` locally with real values:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

The committed template is:

```text
android/key.properties.example
```

## Build Signed AAB

Use real Supabase values locally or from CI secrets, but never commit them:

```powershell
flutter build appbundle --release ^
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" ^
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Play Console

- Upload `app-release.aab` to the closed testing track.
- Do not upload a debug APK.
- Do not upload an APK if Play Console expects an AAB.
- Do not commit generated APK/AAB files.
- Play Console upload remains a manual step.

## Safety Warnings

- Do not share the keystore.
- Do not lose the keystore or passwords.
- Do not send the keystore through chat.
- Do not commit `android/key.properties`.
- Do not commit `android/app/upload-keystore.jks`.
- Do not put a Supabase `service_role` key in Flutter.
- Pass the Supabase anon/publishable key with `--dart-define`.

## Current Release Audit

- Application ID: `com.matchaman.app`
- Rebuild the signed AAB if this identifier changes before upload.
- App label: `Match A Man`
- Launcher icon: `@mipmap/ic_launcher`
- Current `pubspec.yaml` version: `1.0.0+1`
- Current versionName: `1.0.0`
- Current versionCode: `1`
- Release signing reads local `android/key.properties` when present.
- Release builds fail with a signing setup message if local signing files are
  missing.
- Debug builds do not require release signing files.
