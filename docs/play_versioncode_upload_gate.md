# Play VersionCode Upload Gate

Current project version from `pubspec.yaml`:

```text
version: 1.0.0+1
```

Current Play values:

```text
versionName = 1.0.0
versionCode = 1
```

## Rules

- Every new Play upload must increment `versionCode`.
- First closed test upload can use the current project value `1.0.0+1` if no
  previous Play upload has used versionCode `1`.
- If uploading a second AAB to the same app, increase the number after `+` by
  1, for example `1.0.0+2`.
- Do not bump version randomly without upload intent.
- Keep version changes intentional and tied to a real Play upload.

## If Play Rejects The AAB

If Play Console says the versionCode was already used:

1. Update `pubspec.yaml` versionCode only, for example `1.0.0+2`.
2. Run `flutter pub get` if needed.
3. Rebuild the signed AAB.
4. Upload the new AAB.
