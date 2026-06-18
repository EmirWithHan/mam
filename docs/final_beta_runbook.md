# Final Beta Runbook

Use real Supabase values only in your local terminal or secure CI secrets. Keep
all docs and scripts placeholder-only.

## Distribution Pack

- Master launch timeline: `docs/master_launch_timeline.md`
- Critical path checklist: `docs/critical_path_checklist.md`
- Prompt status board: `docs/prompt_status_board.md`
- Manual decision guide: `docs/manual_decision_guide.md`
- Next actions checklist: `docs/next_actions_checklist.md`
- Final APK smoke test checklist:
  `docs/final_apk_smoke_test_checklist.md`
- First 3 tester rollout plan:
  `docs/first_3_tester_rollout_plan.md`
- First 3 tester WhatsApp messages:
  `docs/first_3_tester_whatsapp_messages_tr.md`
- First 3 tester bug intake:
  `docs/first_3_tester_bug_intake.md`
- Tester recruitment message: `docs/tester_recruitment_message_tr.md`
- APK distribution message: `docs/apk_distribution_message_tr.md`
- Short bug report template: `docs/beta_bug_report_short_template.md`
- Tester tracking template: `docs/templates/beta_tester_tracking.csv`
- APK beta operating plan: `docs/apk_beta_operating_plan.md`
- Tester task checklist: `docs/beta_tester_task_checklist_tr.md`
- Known beta limitations: `docs/beta_known_limitations.md`
- Beta feedback master board: `docs/beta_feedback_master_board.md`
- Beta bug severity rubric: `docs/beta_bug_severity_rubric.md`
- Android beta bug report template:
  `docs/templates/android_beta_bug_report_template_tr.md`
- Beta sweep meeting checklist:
  `docs/beta_sweep_meeting_checklist.md`
- Launch candidate criteria: `docs/launch_candidate_criteria.md`
- Feature freeze until launch: `docs/feature_freeze_until_launch.md`

## Play Closed Test Pack

- Pre-submission gate: `docs/play_closed_test_pre_submission_gate.md`
- Form-by-form checklist: `docs/play_console_form_by_form_checklist.md`
- Private values checklist: `docs/play_private_values_checklist.md`
- Tester operations: `docs/play_closed_test_tester_operations.md`
- Opt-in message: `docs/play_closed_test_opt_in_message_tr.md`
- Release notes: `docs/play_closed_test_release_notes_tr.md`
- Final commands: `docs/play_closed_test_final_commands.md`

Final Play Console upload is manual. A signed AAB is still required before
upload, and real tester emails must remain private.

## Analyze And Test

```powershell
flutter analyze
flutter test
```

## Android Debug APK

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Copy APK for manual sharing:

```powershell
copy build\app\outputs\flutter-apk\app-debug.apk "$env:USERPROFILE\Desktop\Match_A_Man_debug.apk"
```

Do not commit the copied APK.

## Android Release AAB

Use for Play Console upload after release signing is configured:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## iOS Future IPA

Run only on macOS with Xcode and Apple signing configured:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/ios/ipa/*.ipa
```

## Rules

- Do not commit build outputs.
- Do not commit real Supabase values.
- Do not commit `android/key.properties`.
- Do not commit keystores, `.jks`, `.keystore`, Apple certificates,
  provisioning profiles, `.p8` files, or IPA files.
- Do not use a Supabase `service_role` key in Flutter.
- Firebase/push remains postponed.
- New product features remain frozen until launch unless they directly fix a
  BLOCKER or HIGH core-flow issue.
