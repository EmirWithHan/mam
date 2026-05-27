# Android Release Checklist

## Current Status

- Android namespace: `com.example.mam`
- Android applicationId: `com.example.mam`
- App label: `MaM`
- Version/build comes from Flutter: `1.0.0+1`
- minSdk/targetSdk/compileSdk use Flutter defaults from the installed toolchain.
- Main manifest includes internet and location permissions.
- Release build currently signs with debug config.

## Blockers Before Play Testing

- Replace placeholder package id with final unique applicationId.
- Configure release signing key.
- Do not commit keystore files, passwords, or Play signing secrets.
- Create/prepare Play Console account.
- Prepare internal or closed testing track.
- Publish Privacy Policy URL.
- Draft Play Data Safety form.
- Prepare screenshots and feature graphic.
- Complete content rating.
- Prepare tester invite plan and reviewer notes.

## Release Command Placeholder

```bash
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
