# Versioning

Date: 2026-06-07

Flutter uses this format in `pubspec.yaml`:

```text
version: versionName+versionCode
```

`versionName` is the human-readable version shown to users. `versionCode` is
the integer Play Store uses to decide whether a build is newer.

Current repo value:

```text
version: 1.0.0+1
versionName: 1.0.0
versionCode: 1
```

For the first Play Console closed testing upload, `1.0.0+1` is acceptable if
`versionCode` `1` has not already been uploaded. If Play Console has already
seen `versionCode` `1`, increase the number after `+` before uploading again.

Every Play Store upload must increase `versionCode`.

Examples:

```text
1.0.0+1
1.0.0+2
1.0.1+3
1.1.0+4
```

Safe bump process:

1. Edit `pubspec.yaml`.
2. Increase only the number after `+` for a rebuild of the same user-facing
   version.
3. Increase the semantic version before `+` only when the user-facing release
   version should change.
4. Run `flutter analyze` and `flutter test`.
5. Build the signed AAB again.

Do not bump the version unless preparing a new Play upload.
