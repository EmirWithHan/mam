# Beta Bug Severity Rubric

Use severity to stop feature creep and decide what must be fixed before launch.

## BLOCKER

- App cannot be installed.
- App does not open.
- White screen/crash on launch.
- Signup/login impossible.
- Verification email impossible.
- `E-postanı doğrula` missing after signup.
- Username onboarding impossible.
- User cannot enter main app after verification.
- Home/Events/Profile completely broken.
- Privacy/security issue.
- Raw secrets exposed.
- Destructive account bug.

Decision: stop rollout or launch. Create a hotfix prompt and verify on device.

## HIGH

- Core screen partly broken.
- Event detail/create broken.
- Repeated permission/RLS issue in core flows.
- Deep link broken but workaround exists.
- Forgot password broken.
- Account deletion path broken before store submission.
- Severe UI overflow blocking button.

Decision: fix before public launch; fix before wider beta if it affects core
flows.

## MEDIUM

- Workaround exists.
- One device-specific UI bug.
- Slow load but usable.
- Non-core screen issue.
- Confusing copy.

Decision: defer unless cheap and low risk.

## LOW

- Typo.
- Spacing.
- Cosmetic polish.
- Nice-to-have.

Decision: defer unless it is quick and clearly safe.

## Feature Requests

- Feature requests are not bugs.
- New features do not enter launch unless they fix a blocker.
- Firebase/push notifications remain postponed.
- Apple Sign In remains postponed unless App Store review requires it later.
