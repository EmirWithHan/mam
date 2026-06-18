# Launch Candidate Criteria

Match A Man can be considered a launch candidate only when every required item
is true.

## Required

- No BLOCKER bugs open.
- No HIGH auth/onboarding bugs open.
- Android install/open/register/verify/username/main flows pass.
- iOS TestFlight launch/register/verify/username/main flows pass if iOS launch
  is included.
- Account deletion path/URL is ready for store submissions.
- Privacy policy URL is ready.
- Store Data Safety/App Privacy answers reflect actual behavior.
- Reviewer test accounts work.
- No secrets committed.
- App icon/label correct.
- Version/build numbers valid.
- Store screenshots do not contain private data.
- Public launch hard gate passes.
- Post-launch monitoring plan is ready.

## Allowed Open Issues

- LOW polish.
- MEDIUM issues with clear workaround.
- Post-launch feature requests.

## Not Launch Candidate If

- Email verification UX broken.
- Deep link blocks verification or password reset with no workaround.
- Main navigation crashes.
- Raw backend errors are common.
- Account deletion/legal missing.
- Play/App Store metadata inaccurate.
- Public launch hard gate contains any `NO` item.

## Public Launch Gate

Before production/App Store submission, complete:

- `docs/public_launch_hard_gate.md`
- `docs/android_production_submission_checklist.md`
- `docs/ios_app_store_submission_checklist.md`
- `docs/store_metadata_final_consistency_check.md`
- `docs/public_launch_hotfix_policy.md`
