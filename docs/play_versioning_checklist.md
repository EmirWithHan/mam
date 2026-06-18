# Play Versioning Checklist

## Current Version

Current `pubspec.yaml` version:

```text
1.0.0+1
```

This maps to:

- versionName: `1.0.0`
- versionCode: `1`

## Play Upload Rule

Every Google Play upload must use a versionCode that is greater than every
previous uploaded build.

If `1.0.0+1` has already been uploaded, the next upload must increase the value
after `+`, for example:

```yaml
version: 1.0.0+2
```

## Suggested Closed Test Versioning

If no Play upload has been made yet, `1.0.0+1` can be used for the first closed
test build.

If you want a beta-style version before upload, use:

```yaml
version: 0.1.0+1
```

Then the next closed test upload would be:

```yaml
version: 0.1.0+2
```

Do not bump the version unless you are preparing a new Play upload.

## Manual Checklist

- [ ] Confirm the latest uploaded Play Console versionCode.
- [ ] Confirm the next versionCode is higher.
- [ ] Confirm release notes match the uploaded version.
- [ ] Confirm the AAB file was built after the version change.
- [ ] Do not change package/application ID when bumping version.
