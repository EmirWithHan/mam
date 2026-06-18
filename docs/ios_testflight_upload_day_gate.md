# iOS TestFlight Upload Day Gate

Do not rent MacInCloud unless every required item is `YES`.

## Required Checklist

| Item | YES/NO | Blocker / Notes |
| --- | --- | --- |
| Apple Developer Program active. |  |  |
| App Store Connect login works. |  |  |
| No blocking agreements in App Store Connect. |  |  |
| Bundle ID finalized: `com.matchaman.app`. |  |  |
| App Store Connect app record can be created. |  |  |
| Latest code pushed to GitHub. |  |  |
| Android/auth/onboarding final state pushed. |  |  |
| Supabase redirect URL includes `matchaman://auth/callback`. |  |  |
| Supabase redirect URL includes `matchaman://reset-password`. |  |  |
| iOS URL scheme configured in `Info.plist`. |  |  |
| App icon source ready. |  |  |
| App display name is `Match A Man`. |  |  |
| Supabase URL and anon key available privately for dart-defines. |  |  |
| Apple ID 2FA device is available. |  |  |
| Reviewer/test account plan exists. |  |  |
| Privacy policy URL status known. |  |  |
| Account deletion URL status known. |  |  |

## Decision

```text
MACINCLOUD_READY = yes/no
TESTFLIGHT_UPLOAD_DAY_READY = yes/no
```

If any required item is `NO`, do not rent MacInCloud yet. Write the exact
blocker in the Notes column and fix it before paid Mac time starts.
