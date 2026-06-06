# Versioning

Date: 2026-06-06

Flutter uses this format in `pubspec.yaml`:

```text
version: versionName+versionCode
```

Example:

```text
version: 1.0.0+1
```

`versionName` is the human-readable version shown to users. `versionCode` is the
integer Play Store uses to decide whether a build is newer.

Every Play Store upload must increase `versionCode`. For example:

```text
0.1.0+1
0.1.0+2
0.1.1+3
1.0.0+4
```

Closed beta can use `0.1.0+1` or a similar pre-release value if the project has
not already settled on `1.0.0+1`. The current repo value is:

```text
version: 1.0.0+1
```

Do not change the version automatically during signing setup. Increase
`versionCode` only when preparing a new Play Console upload.
