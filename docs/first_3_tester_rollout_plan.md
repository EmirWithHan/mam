# First 3 Tester Rollout Plan

## Purpose

The first 3 testers are only for blocker detection. Do not send the APK to a
wider group until these testers can install, register, verify email, complete
username onboarding, and open the core screens.

## Tester Criteria

- Has an Android phone.
- Uses Gmail or another real email account.
- Can send screenshot/video.
- Understands the app is beta and may have bugs.
- Close enough to give fast feedback.
- Will not share passwords or private verification links.

## Rollout Steps

1. Build APK.
2. Install on own phone first.
3. Run smoke test from `docs/final_apk_smoke_test_checklist.md`.
4. Send APK to tester 1.
5. Wait for install/register result.
6. Send APK to tester 2.
7. Wait for install/register result.
8. Send APK to tester 3.
9. Collect feedback for 24 hours.
10. Fix blockers before expanding to 8-12 testers.
11. Add every report to `docs/beta_feedback_master_board.md`.
12. Classify each report using `docs/beta_bug_severity_rubric.md`.

## Stop Conditions

Stop rollout if any tester reports:

- Cannot install.
- Registration broken.
- Email verification broken.
- Username onboarding broken.
- Home, Events, or Profile broken.
- White screen or crash.
- Privacy/security issue.

## Output

- First 3 tester result list.
- Blocker list if any.
- Decision: expand to 8-12 testers or fix first.

## Feedback Docs

- Feedback board: `docs/beta_feedback_master_board.md`
- Severity rubric: `docs/beta_bug_severity_rubric.md`
- Android report template:
  `docs/templates/android_beta_bug_report_template_tr.md`
- Hotfix prompt template: `docs/templates/hotfix_prompt_template.md`
