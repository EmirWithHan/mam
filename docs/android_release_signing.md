# Android Release Signing

Date: 2026-06-06

## What Signing Is

Debug APKs are for development and internal testing. Play Store release builds
should be signed Android App Bundles (`.aab`).

Google Play uses Play App Signing. The developer keeps an upload key locally and
uses that upload key to sign release AAB files before uploading them to Play
Console.

Keystores, passwords, `key.properties`, and real Supabase values must never be
committed, uploaded to GitHub, or shared in chat.

## Local Files To Create Later

Create these files only on the local build machine:

```text
android/key.properties
android/app/upload-keystore.jks
```

The repo contains only this safe placeholder template:

```text
android/key.properties.example
```

## Generate Upload Key

Run this from the project root and choose strong passwords:

```powershell
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Store a backup securely. Do not upload the keystore to GitHub. Do not send the
keystore or passwords in chat.

## Local Key Properties Template

Create `android/key.properties` locally with real values:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

The committed app Gradle config reads this file only if it exists. Debug builds
do not require it. Release builds fail with a signing setup message until the
local file and keystore exist.

## Release AAB Build

Run from the project root with local or CI secret values:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Release Split APK Test Build

Use split APKs for direct install testing when needed:

```powershell
flutter build apk --release --split-per-abi `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Modern Android phones usually use:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Play Console Notes

- Upload the release AAB, not a debug APK.
- Follow the Play Console Play App Signing flow.
- Data Safety, privacy policy, screenshots, store listing, and closed testing
  track setup are separate tasks.
- Do not upload debug builds.
- Do not hardcode Supabase URL/key in the repo; pass them with `--dart-define`.
