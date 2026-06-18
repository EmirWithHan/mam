# First 3 Tester Bug Intake

Use this when a close tester reports an issue.

## Severity

### BLOCKER

- Cannot install.
- Cannot open.
- Cannot register/login.
- Email verification impossible.
- Username onboarding impossible.
- Main app unusable.
- Crash/white screen.
- Privacy/security issue.

### HIGH

- Major screen broken.
- Events/Profile/Home broken.
- Wrong permission errors.
- Repeated `Bir şeyler ters gitti`.

### MEDIUM

- Workaround exists.
- UI overflow on one device.
- Slow load.
- Non-core flow issue.

### LOW

- Text/polish.
- Minor layout issue.
- Small copy confusion.

## Required Report Format

- Phone model:
- Android version:
- Screen/page:
- What happened:
- Expected result:
- Screenshot/video:
- Approx time:
- Account email if needed:
- Severity:

Never ask testers for passwords. Do not ask them to forward verification links
unless absolutely necessary, and never paste private auth links into public
issues or docs.

## Intake Decision

- BLOCKER: stop rollout and fix before sending to more testers.
- HIGH: fix before wider 8-12 tester group unless clearly isolated.
- MEDIUM: track and fix after blocker path is stable.
- LOW: keep for polish batch.
