# Signed AAB Pre-Build Gate

Do not build or upload a Play closed testing AAB unless every BLOCKER item is
`YES`.

## BLOCKER Checklist

| Item | YES/NO | Notes |
| --- | --- | --- |
| Email confirmation pending screen appears immediately after signup. |  |  |
| Verification email arrives. |  |  |
| Username onboarding works. |  |  |
| Home opens. |  |  |
| Events opens. |  |  |
| Profile opens. |  |  |
| Settings opens. |  |  |
| App icon is correct. |  |  |
| App label is `Match A Man`. |  |  |
| No raw backend errors appear on normal flows. |  |  |
| No secrets are committed. |  |  |
| `key.properties` is ignored. |  |  |
| `upload-keystore.jks` is ignored. |  |  |
| `versionCode` is valid. |  |  |
| Privacy/account deletion/reviewer docs are ready enough for closed test. |  |  |

## Decision

```text
SIGNED_AAB_BUILD_READY = yes/no
PLAY_CLOSED_TEST_UPLOAD_READY = yes/no
```

If any auth, onboarding, core screen, signing, version, or privacy/reviewer item
is `NO`, stop and fix before uploading to Play Console.
