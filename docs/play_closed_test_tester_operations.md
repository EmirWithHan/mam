# Play Closed Test Tester Operations

## 1. Tester Collection

- Collect Android testers privately.
- Ask for Google Play email.
- Ask for phone model.
- Ask for Android version.
- Do not commit tester emails to the repository.

## 2. Tester Onboarding Message

Use `docs/play_closed_test_opt_in_message_tr.md`.

The message should explain:

- They will receive a Play Store closed test link.
- They must join the test from the opt-in link.
- They must install the app from Play Store.
- They should use a real email in the app.
- They should verify their email.
- They should choose a username.
- They should test core flows.
- They should send screenshot/video if a bug happens.

## 3. Daily Operations

### Day 0

- Upload release.
- Add testers.
- Send opt-in link.

### Day 1

- Confirm testers can install.
- Confirm signup/login works.
- Confirm no startup blocker exists.

### Days 2-6

- Collect bugs.
- Prioritize auth, Home, Events, Profile, Search, Settings, feedback, and
  account deletion/request path.

### Day 7

- Run a mid-test bug sweep.
- Decide whether a new build is needed.

### Days 8-13

- Verify stability.
- Retest fixed blocker/high issues.
- Keep testers opted in.

### Day 14

- Prepare production readiness decision.
- Summarize bugs found, fixes made, remaining risks, and tester engagement.

## 4. Tester Status Template

Use `docs/templates/beta_tester_tracking.csv` as a template.

Real tracking files should be local/private and must not be committed.

## 5. Bug Triage

- Use `docs/beta_feedback_master_board.md` for all tester reports.
- Use `docs/beta_bug_severity_rubric.md` for severity.
- Use `docs/templates/android_beta_bug_report_template_tr.md` when asking for
  missing details.
- Use `docs/beta_sweep_meeting_checklist.md` for daily/weekly triage.
- Use `docs/templates/hotfix_prompt_template.md` for BLOCKER/HIGH fixes.

Severity summary:

- BLOCKER: app cannot be used.
- HIGH: main flow broken.
- MEDIUM: workaround exists.
- LOW: polish.

Feature requests should be deferred according to
`docs/feature_freeze_until_launch.md`.
