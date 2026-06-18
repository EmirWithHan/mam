# Launch Candidate Report

Date: 2026-06-07

## Summary

- Android APK beta: ready for controlled friends/internal tester APK beta after
  building locally with real `--dart-define` values and running one final smoke
  test.
- Play Store closed testing: not ready for upload yet. The preparation docs are
  in place, but a signed release AAB, final screenshots, Play Console form
  entries, tester list, and live account/privacy URLs still need manual work.
- iOS TestFlight preparation: ready to continue preparation. Code/prep is in
  good shape, but real TestFlight distribution still needs Apple Developer
  Program access, signing, a signed IPA, and App Store Connect setup.

## What Works

- Supabase Auth remains the source of truth.
- Email/password signup uses link-based email confirmation.
- The app shows the email verification pending flow after signup.
- Unverified email/password users are blocked from the main shell.
- Password reset link flow and reset password screen exist.
- Verified users without usernames are routed to username onboarding.
- Username is the only required onboarding step after verified auth.
- Full profile completion remains optional and can be done later.
- Home, Events, Event detail, Create event, Profile, Search, Notifications,
  Settings, legal pages, feedback, and account deletion/request paths are
  present in the app/docs checklist.
- Android app label is `Match A Man`.
- Android and iOS launcher icons use the Match A Man logo, not the default
  Flutter logo.
- Android deep links exist for email confirmation and password reset.
- iOS URL scheme exists for the shared `matchaman` deep link flow.
- iOS no-codesign workflow exists and uses no signing secrets.
- Friendly error handling is covered by tests for generic and permission
  errors.

## Known Limitations

- Firebase/push notifications are intentionally postponed.
- Play Store closed testing still requires a signed release AAB.
- App Store/TestFlight still requires Apple Developer signing and upload.
- Account deletion web URL/page may still need hosted production deployment.
- Store screenshots and final visual assets still need final capture/export.
- Real-device QA must still be repeated on the final build sent to testers.
- Local `.local.ps1` build scripts may contain real local values and must stay
  ignored/untracked.
- Tester distribution pack exists for recruitment, APK sharing, task checklist,
  bug reports, tester tracking, operating plan, and known limitations.
- Play closed test submission pack exists for pre-submission gate,
  form-by-form Play Console setup, private values, tester operations, opt-in
  message, release notes, and final commands.
- iOS MacInCloud/TestFlight prep pack exists for Apple Developer readiness,
  signing notes, build-day runbook, deep link checks, App Store Connect
  metadata, internal beta, and paid-session risks.
- iOS TestFlight upload-day pack exists for the rent-or-wait gate,
  MacInCloud session, Xcode signing, IPA upload troubleshooting, first build
  smoke test, and App Store review notes draft.
- Android+iOS simultaneous launch master plan exists for timeline, blockers,
  prompt status, manual decisions, and next actions.
- Android+iOS beta feedback system exists for bug intake, severity, sweep
  meetings, launch candidate criteria, decision tree, hotfix prompts, and
  feature freeze.
- Public launch submission pack exists for production/App Store hard gate,
  platform submission checklists, metadata consistency, announcement drafts,
  monitoring, review rejection response, and launch-week hotfix policy.

## Blockers

### BLOCKER

- None for controlled friends Android APK beta, assuming the APK is built with
  real Supabase dart-defines and passes the final smoke test.
- Launch candidate status must be recalculated from
  `docs/beta_feedback_master_board.md` after real tester feedback arrives.

### HIGH

- Play Store closed testing needs a signed release AAB.
- Play Console needs final tester list, app access instructions, Data Safety,
  privacy/account deletion URLs, and screenshots.
- iOS TestFlight distribution needs Apple Developer Program access, App Store
  Connect app record, signing certificate/profile, signed IPA, and upload.
- Hosted account deletion/privacy URLs must be finalized before public store
  submission.

### MEDIUM

- iOS real-device deep link behavior still needs validation on an iPhone.
- Final Android tester feedback may reveal device-specific overflow or auth
  edge cases.
- Store metadata must avoid overclaiming safety, verification, or official
  event supervision.

### LOW

- Some older docs may still contain encoding artifacts from previous Turkish
  text edits.
- Final screenshots and tester-facing copy can be polished after beta feedback.

## Decision

```text
APK_BETA_READY = yes
PLAY_CLOSED_TEST_READY = no
IOS_TESTFLIGHT_PREP_READY = yes
PUBLIC_LAUNCH_READY = no
```

`PLAY_CLOSED_TEST_READY = no` means the app is not ready to upload to the Play
Console closed testing track today. The code/docs prep are close, but store
submission artifacts and manual console setup remain.

`IOS_TESTFLIGHT_PREP_READY = yes` means the repository is ready to continue the
iOS signing/TestFlight path. It does not mean TestFlight distribution is already
complete.

`PUBLIC_LAUNCH_READY = no` means production/App Store submission should not be
recommended until beta feedback, store URLs, signed builds, screenshots,
metadata, and `docs/public_launch_hard_gate.md` all pass.

## Secret Scan Result

- No tracked Flutter source was found with a `service_role` key.
- No tracked Flutter source was found with hardcoded real Supabase URL/anon key.
- `android/key.properties` is absent.
- `android/app/upload-keystore.jks` is absent.
- Apple signing secrets, `.p8` files, certificates, provisioning profiles, and
  IPA outputs were not found in tracked files during this sweep.
- Ignored local scripts under `scripts/*.local.ps1` contain local Supabase build
  values. They are untracked and ignored; keep them that way.
- Placeholder values in docs/scripts are allowed.

## Next Manual Steps

### APK Beta

1. Build the debug APK locally with real Supabase dart-defines.
2. Uninstall old builds from the Android phone.
3. Install the new APK.
4. Run the final smoke test:
   auth, email confirmation, username onboarding, Home, Events, Profile, Search,
   Notifications, Settings, feedback, legal pages, account deletion/request.
5. Send the tester message in `docs/final_beta_tester_message_tr.md`.
6. Use `docs/apk_distribution_message_tr.md`,
   `docs/beta_tester_task_checklist_tr.md`, and
   `docs/beta_bug_report_short_template.md`.
7. Track tester status from a private copy of
   `docs/templates/beta_tester_tracking.csv`.
8. Collect screenshot/video, device model, Android version, account used, and
   approximate time for bugs.

### Play Store Closed Test

1. Create local release keystore and `android/key.properties` outside Git.
2. Build the signed release AAB with real local/CI secrets.
3. Upload the AAB to Play Console closed testing.
4. Add tester emails in Play Console or private tracking, not in the repo.
5. Enter Data Safety, app access, privacy policy URL, account deletion URL, and
   reviewer instructions.
6. Complete `docs/play_closed_test_pre_submission_gate.md`.
7. Complete `docs/play_console_form_by_form_checklist.md`.
8. Upload final screenshots and listing assets.
9. Submit closed testing for review.

### iOS

1. Activate/confirm Apple Developer Program access.
2. Create the App Store Connect app.
3. Register/confirm Bundle ID `com.matchaman.app`.
4. Configure signing certificate and provisioning profile.
5. Use Mac, MacinCloud, or secure CI with signing secrets.
6. Build the signed IPA.
7. Upload to TestFlight.
8. Run internal TestFlight smoke testing before external beta.
9. Follow `docs/macincloud_ios_build_day_runbook.md` if using MacInCloud.
10. Complete `docs/ios_testflight_upload_day_gate.md` before renting Mac time.

## Notes

- No Firebase/push was added.
- No new product features were added.
- Do not commit generated APK/AAB/IPA files.
- Do not commit real Supabase values, keystores, Apple credentials, reviewer
  passwords, or other secrets.

## Tester Distribution Pack

- `docs/tester_recruitment_message_tr.md`
- `docs/apk_distribution_message_tr.md`
- `docs/beta_bug_report_short_template.md`
- `docs/templates/beta_tester_tracking.csv`
- `docs/apk_beta_operating_plan.md`
- `docs/beta_tester_task_checklist_tr.md`
- `docs/beta_known_limitations.md`

## Play Closed Test Submission Pack

- `docs/play_closed_test_pre_submission_gate.md`
- `docs/play_console_form_by_form_checklist.md`
- `docs/play_private_values_checklist.md`
- `docs/play_closed_test_tester_operations.md`
- `docs/play_closed_test_opt_in_message_tr.md`
- `docs/play_closed_test_release_notes_tr.md`
- `docs/play_closed_test_final_commands.md`

## iOS MacInCloud And TestFlight Pack

- `docs/ios_apple_developer_readiness_checklist.md`
- `docs/macincloud_ios_build_day_runbook.md`
- `docs/ios_bundle_id_and_signing_notes.md`
- `docs/ios_deep_link_test_checklist.md`
- `docs/app_store_connect_metadata_prep.md`
- `docs/testflight_internal_beta_checklist.md`
- `docs/macincloud_risk_checklist.md`
- `docs/ios_testflight_upload_day_gate.md`
- `docs/macincloud_session_checklist.md`
- `docs/xcode_signing_checklist.md`
- `docs/ios_ipa_upload_troubleshooting.md`
- `docs/testflight_first_build_checklist.md`
- `docs/app_store_review_notes_draft.md`

## Simultaneous Launch Master Pack

- `docs/master_launch_timeline.md`
- `docs/critical_path_checklist.md`
- `docs/prompt_status_board.md`
- `docs/manual_decision_guide.md`
- `docs/next_actions_checklist.md`

## Beta Feedback And Launch Candidate Pack

- `docs/beta_feedback_master_board.md`
- `docs/beta_bug_severity_rubric.md`
- `docs/templates/android_beta_bug_report_template_tr.md`
- `docs/templates/ios_testflight_bug_report_template_tr.md`
- `docs/beta_sweep_meeting_checklist.md`
- `docs/launch_candidate_criteria.md`
- `docs/beta_to_launch_decision_tree.md`
- `docs/templates/hotfix_prompt_template.md`
- `docs/feature_freeze_until_launch.md`

## Public Launch Submission Pack

- `docs/public_launch_hard_gate.md`
- `docs/android_production_submission_checklist.md`
- `docs/ios_app_store_submission_checklist.md`
- `docs/store_metadata_final_consistency_check.md`
- `docs/public_launch_announcement_tr.md`
- `docs/post_launch_monitoring_plan.md`
- `docs/templates/store_review_rejection_response_template.md`
- `docs/public_launch_hotfix_policy.md`
