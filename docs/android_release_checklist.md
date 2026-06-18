# Android Release Checklist

## Current Status

- Android namespace: `com.matchaman.app`
- Android applicationId: `com.matchaman.app`
- Rebuild the signed AAB after any applicationId change; do not upload an AAB
  built with an older id.
- App label: `MaM`
- Version/build comes from Flutter: `1.0.0+1`
- minSdk/targetSdk/compileSdk use Flutter defaults from the installed toolchain.
- Main manifest includes internet and location permissions.
- Release builds require local signing config and use `signingConfigs.release`.
- Release AAB tasks fail if `android/key.properties` is missing.

## Blockers Before Play Testing

- Verify Play Console app record uses `com.matchaman.app`.
- Generate local upload keystore and create `android/key.properties`.
- Do not commit keystore files, passwords, or Play signing secrets.
- Create/prepare Play Console account.
- Enroll in Play App Signing manually.
- Prepare internal or closed testing track.
- Publish Privacy Policy URL.
- Draft Play Data Safety form.
- Prepare screenshots and feature graphic.
- Complete content rating.
- Prepare tester invite plan and reviewer notes.

## Local Release Signing

Generate the upload keystore manually outside Git:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` manually with local values only:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../app/upload-keystore.jks
```

Never commit `android/key.properties`, `*.jks`, or `*.keystore` files.

## Release AAB Command

```bash
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

Upload to Play Console closed testing manually. Store listing, Data Safety,
content rating, privacy URL, account deletion URL, and tester setup remain
manual Play Console steps.
