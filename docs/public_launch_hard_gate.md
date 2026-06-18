# Public Launch Hard Gate

Do not submit to Google Play production or Apple App Store review unless every
REQUIRED item is `YES`.

## Product/Core

| Required item | YES/NO | Blocker notes |
| --- | --- | --- |
| No open BLOCKER bugs. |  |  |
| No open HIGH auth/onboarding/main-navigation bugs. |  |  |
| Register works. |  |  |
| `E-postanı doğrula` screen appears immediately after signup. |  |  |
| Verification email arrives. |  |  |
| Verified user can continue to username onboarding. |  |  |
| Username onboarding works. |  |  |
| Login works. |  |  |
| Logout works. |  |  |
| Forgot password works or limitation is documented before launch. |  |  |
| Home works. |  |  |
| Events works. |  |  |
| Event detail works. |  |  |
| Create event works or limitation documented. |  |  |
| Profile works. |  |  |
| Search works. |  |  |
| Settings works. |  |  |
| Account deletion/request path works. |  |  |
| No white screen on normal flow. |  |  |
| No common raw Supabase/Postgrest errors shown to users. |  |  |

## Android

| Required item | YES/NO | Blocker notes |
| --- | --- | --- |
| Signed AAB builds. |  |  |
| `versionCode` incremented. |  |  |
| App icon correct. |  |  |
| App label `Match A Man`. |  |  |
| Play Store listing complete. |  |  |
| Data Safety accurate. |  |  |
| Content rating complete. |  |  |
| Privacy policy URL live. |  |  |
| Account deletion URL live. |  |  |
| Reviewer app access instructions ready. |  |  |
| Closed testing obligations met if required. |  |  |
| Production release notes ready. |  |  |

## iOS

| Required item | YES/NO | Blocker notes |
| --- | --- | --- |
| IPA/TestFlight build passed smoke test. |  |  |
| iOS build number incremented. |  |  |
| App icon correct. |  |  |
| Display name `Match A Man`. |  |  |
| App Store metadata complete. |  |  |
| App Privacy answers accurate. |  |  |
| Privacy policy URL live. |  |  |
| Account deletion URL live. |  |  |
| Reviewer notes and test account ready. |  |  |
| TestFlight internal/external beta passed if used. |  |  |
| No signing/capability mismatch. |  |  |

## Security/Legal

| Required item | YES/NO | Blocker notes |
| --- | --- | --- |
| No secrets committed. |  |  |
| No `service_role` in Flutter. |  |  |
| No signing files committed. |  |  |
| Privacy policy matches actual data. |  |  |
| Account deletion path is accessible. |  |  |
| Support contact available. |  |  |
| Store screenshots contain no private data. |  |  |

## Decision

```text
PUBLIC_LAUNCH_READY = yes/no
```

If any required item is `NO`, mark `PUBLIC_LAUNCH_READY = no`, list the exact
blockers, and do not recommend production/App Store submission.
