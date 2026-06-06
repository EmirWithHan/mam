# Android Size Optimization

Date: 2026-06-06

## Summary

Debug APKs are naturally large in Flutter because they include debugging
support, multiple ABIs, unshaken assets/icons, and development metadata. A
debug APK around 200 MB is expected and should not be used as the normal
internal testing artifact.

For internal Android testing, prefer a release APK split per ABI. For Google
Play, prefer the release Android App Bundle.

## Build Commands

Use placeholders in docs and scripts. Never hardcode real Supabase values.

Debug APK:

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Split release APKs:

```powershell
flutter build apk --release --split-per-abi `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Release App Bundle:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## Artifact Paths

Debug:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Split release:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

Play Store:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Which File To Install

Use `app-arm64-v8a-release.apk` for most modern Android phones. Use
`app-armeabi-v7a-release.apk` only for older 32-bit devices. Use
`app-x86_64-release.apk` for x86_64 emulator/device testing.

Use `app-release.aab` for Play Console upload. Do not sideload the AAB directly
onto test phones.

## Current Measurement

Measured with placeholder dart-defines on 2026-06-06:

```text
app-debug.apk: 216.62 MB
app-arm64-v8a-release.apk: 20.03 MB
app-armeabi-v7a-release.apk: 17.85 MB
app-x86_64-release.apk: 21.46 MB
app-release.aab: 44.36 MB
```

## Asset And Dependency Notes

Current declared app asset surface is small:

```text
assets/branding/mam_logo.jpg: 33.37 KB
```

No large screenshots, mockups, duplicate images, custom fonts, or unused
generated assets are declared for the Android app bundle.

No dependency was removed in this pass. `cupertino_icons` is retained because
the release build expects the package font, and Flutter tree-shakes it to under
1 KB in release output. Other size-relevant dependencies are currently used by
app code:

- `cupertino_icons`
- `geocoding`
- `geolocator`
- `google_fonts`
- `go_router`
- `image_picker`
- `supabase_flutter`
- `url_launcher`

## Rules

- Never commit generated APK or AAB files.
- Never commit local scripts with real Supabase values.
- Never hardcode real Supabase keys in source, docs, or example scripts.
- Keep using the public Supabase anon/publishable key only; never ship the
  service-role key.
- Do not add Firebase or push setup as part of size optimization.
