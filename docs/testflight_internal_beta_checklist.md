# TestFlight Internal Beta Checklist

Use internal TestFlight before inviting external testers.

## App Store Connect Setup

- App record exists for `com.matchaman.app`.
- Signed build uploaded and processed.
- Internal testing group exists.
- Internal testers are App Store Connect users.
- Beta app description is filled.
- Export compliance answers are completed.
- No real reviewer credentials are stored in this repo.

## Install Smoke Test

- Install from the TestFlight app.
- Launch the app.
- Confirm app name is `Match A Man`.
- Confirm app icon is the Match A Man logo.
- Confirm no Firebase/push permission prompt appears.
- Confirm no Flutter default icon appears in app switcher.

## Core Flow Smoke Test

- Register with email/password.
- Confirm `E-postanı doğrula` appears.
- Confirm email link.
- Log in after verification.
- Complete username onboarding.
- Open Home.
- Open Events.
- Open Event detail.
- Create a test event if the account is allowed.
- Open Profile.
- Open Kullanıcı ara.
- Open Notifications.
- Open Settings.
- Open legal pages.
- Submit feedback if the beta environment allows it.
- Test forgot password and reset link.
- Confirm account deletion/request path is reachable.

## iOS-Specific Checks

- Safe areas are respected on notched devices.
- Keyboard does not cover primary form buttons.
- Long event/profile names ellipsize or wrap correctly.
- Photo permission text is Turkish.
- Location permission text is Turkish.
- Email confirmation and password reset deep links return to the app.

## Before External TestFlight

- Internal install succeeds on at least one real iPhone.
- Blocking login/auth/deep link issues are fixed.
- Beta review notes are ready.
- Tester instructions link to `docs/testflight_plan.md`.
- Known limitations are documented without overclaiming safety or moderation.

## Feedback Triage

- Use `docs/beta_feedback_master_board.md` for all iOS reports.
- Use `docs/beta_bug_severity_rubric.md` for severity.
- Use `docs/templates/ios_testflight_bug_report_template_tr.md` for tester
  report details.
- Use `docs/beta_sweep_meeting_checklist.md` during internal/external beta.
- Use `docs/launch_candidate_criteria.md` before App Store review decisions.
- Use `docs/feature_freeze_until_launch.md` to defer feature requests.
