# Critical Path Checklist

Use this as the blocker gate for each launch phase.

## BLOCKER BEFORE APK BETA

- [ ] Email confirmation pending screen missing after signup.
- [ ] Signup/login broken.
- [ ] Username onboarding broken.
- [ ] Home, Events, or Profile broken.
- [ ] White screen or crash.
- [ ] App icon still shows Flutter logo.
- [ ] Raw backend error appears in normal user flow.
- [ ] Supabase dart-defines missing in build.

## BLOCKER BEFORE PLAY CLOSED TEST

- [ ] Signed AAB cannot be built.
- [ ] Play Console app not created.
- [ ] Privacy policy URL missing.
- [ ] Account deletion URL missing or unresolved.
- [ ] Data Safety incomplete.
- [ ] Reviewer instructions missing.
- [ ] App access test account missing.
- [ ] Screenshots/store listing missing.
- [ ] Keystore or secrets committed.
- [ ] `versionCode` invalid or not incremented for a new upload.

## BLOCKER BEFORE MACINCLOUD

- [ ] Apple Developer not active.
- [ ] App Store Connect inaccessible.
- [ ] Bundle ID undecided.
- [ ] Repo not pushed.
- [ ] Supabase redirect URLs not ready.
- [ ] Apple ID two-factor authentication not ready.
- [ ] No iOS build day runbook.

## BLOCKER BEFORE TESTFLIGHT

- [ ] Signing fails.
- [ ] IPA cannot be built.
- [ ] Upload fails.
- [ ] Deep links fail on iOS.
- [ ] App crashes on launch.
- [ ] Missing privacy metadata.

## BLOCKER BEFORE PUBLIC LAUNCH

- [ ] Public launch hard gate has any `NO` item.
- [ ] Account deletion web URL not live.
- [ ] Privacy/legal text not aligned with actual app behavior.
- [ ] Store Data Safety or App Privacy answers inaccurate.
- [ ] Critical beta bugs unresolved.
- [ ] Any BLOCKER issue remains in `docs/beta_feedback_master_board.md`.
- [ ] HIGH auth/onboarding/main navigation issue remains unresolved.
- [ ] Support/contact missing.
- [ ] Review credentials missing.
- [ ] Production screenshots missing.

## Optional

- [ ] Extra store screenshots.
- [ ] App preview videos.
- [ ] Wider tester pool beyond the first 8-12 trusted testers.
- [ ] Marketing launch announcement.
- [ ] Additional copy polish after legal/store blockers are clear.

## Feedback Decision Docs

- `docs/beta_feedback_master_board.md`
- `docs/beta_bug_severity_rubric.md`
- `docs/launch_candidate_criteria.md`
- `docs/beta_to_launch_decision_tree.md`
- `docs/feature_freeze_until_launch.md`
- `docs/templates/hotfix_prompt_template.md`

## Public Launch Docs

- `docs/public_launch_hard_gate.md`
- `docs/android_production_submission_checklist.md`
- `docs/ios_app_store_submission_checklist.md`
- `docs/store_metadata_final_consistency_check.md`
- `docs/public_launch_announcement_tr.md`
- `docs/post_launch_monitoring_plan.md`
- `docs/templates/store_review_rejection_response_template.md`
- `docs/public_launch_hotfix_policy.md`
