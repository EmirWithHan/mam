# Master Launch Timeline

This is the execution plan for launching Match A Man on Android and iOS as
close together as practical. It keeps Android beta moving while iOS signing and
TestFlight catch up.

## Phase 1 - Final APK Beta Readiness

Goal: send APK to 3 close Android testers.

Required:

- Email confirmation pending screen works after signup.
- Verification email arrives.
- Username onboarding works.
- Home, Events, Profile, Search, and Settings pass own-phone smoke testing.
- App icon is Match A Man, not the Flutter logo.
- No white screen or launch crash.
- No raw backend/Postgrest errors in normal user flows.
- Final tester message is ready.
- Debug APK is built with real local `--dart-define` values.

Output:

- `Match_A_Man_debug.apk` sent manually to 3 close Android testers.

Blocker status:

- Blocker until every required item above passes on the owner's phone.

## Phase 2 - Wider APK Beta

Goal: send APK to 8-12 trusted Android testers.

Required:

- Phase 1 blockers fixed.
- Bug report template ready.
- Tester tracking sheet ready.
- Known limitations note ready.
- Beta feedback board and severity rubric ready.
- First 3 tester results do not reveal a blocker.

Output:

- First real bug list from varied Android devices.

Blocker status:

- Blocker for wider beta if signup/login, main tabs, or Events are broken.

## Phase 3 - Google Play Closed Testing Upload

Goal: upload signed AAB to Play Console closed testing.

Required:

- Signed AAB build path ready.
- Keystore and `android/key.properties` kept local only.
- Play Console app created.
- Store listing draft ready.
- Screenshots ready or minimum acceptable placeholders prepared.
- Privacy policy URL ready.
- Account deletion URL ready or final blocker documented.
- Data Safety draft ready.
- Content rating completed.
- Reviewer app access instructions ready.
- Closed testing track created.
- Tester email list collected privately.
- No APK beta blocker remains.

Output:

- `app-release.aab` uploaded to Play Console closed testing.
- Opt-in link sent to testers.

Blocker status:

- Blocker until signing, store privacy, reviewer access, and account deletion
  requirements are ready.

## Phase 4 - Apple Developer Activation

Goal: prepare official Apple account before renting Mac.

Required:

- Apple Developer purchased officially.
- App Store Connect access works.
- No blocking agreements.
- Bundle ID decision final: `com.matchaman.app`.
- App metadata basics known.
- Privacy/account deletion URL status known.
- Latest repo pushed.

Output:

- iOS signing can be configured later.

Blocker status:

- Blocker before MacInCloud rental, not before Android APK beta.

## Phase 5 - MacInCloud Build Day

Goal: use temporary Mac only when ready.

Required before renting:

- Apple Developer active.
- App Store Connect accessible.
- Repo clean enough for build work and pushed.
- Supabase redirect URLs ready.
- App icon ready.
- Bundle ID known.
- Reviewer/test account notes ready.
- Apple ID two-factor authentication ready.
- MacInCloud runbook ready.
- TestFlight upload day gate complete.
- App Store review notes draft ready with placeholders only.

Mac day tasks:

- Clone repo.
- Check Xcode.
- Check Flutter.
- Run `flutter pub get`.
- Run `pod install`.
- Run simulator build.
- Configure Xcode signing.
- Run `flutter build ipa`.
- Upload to App Store Connect/TestFlight.
- Install TestFlight internal build if possible.
- Run first build checklist before inviting external testers.

Output:

- iOS build uploaded to TestFlight or exact blocker documented.

Blocker status:

- Blocker for iOS beta if signing, IPA build, or upload fails.

## Phase 6 - Android Closed Test And iOS TestFlight Beta

Goal: run both beta tracks close together.

Required:

- Android opt-in testers active.
- iOS internal or external testers invited.
- Bug triage process ready.
- `docs/beta_feedback_master_board.md` is updated from tester reports.
- `docs/beta_bug_severity_rubric.md` is used for every reported issue.
- Mid-test bug sweep scheduled.
- No blocker bugs open.

Output:

- Launch candidate decision.
- Deferred feature/polish list.

Blocker status:

- Blocker for public launch if critical beta bugs remain.

## Phase 7 - Public Launch Readiness

Goal: submit Android production and iOS App Store review when both are stable.

Required:

- Public launch hard gate passes.
- Privacy/legal/account deletion finalized.
- Production store screenshots ready.
- Final Data Safety and App Privacy answers accurate.
- Account deletion web URL live.
- Support URL live.
- No blocker bugs.
- Launch candidate criteria met.
- Release notes ready.
- Production `versionCode` and iOS build number bumped.
- Post-launch monitoring plan ready.
- Public launch hotfix policy accepted.

Output:

- Production submission.
- Public launch monitoring starts.

Blocker status:

- Blocker until store policy, privacy, account deletion, and critical bugs are
  resolved.

## Optional Items

- Extra screenshots beyond minimum store requirements.
- App preview videos.
- More tester message variants.
- Additional marketing copy polish.
- Public launch date announcement.

Optional items should not block closed beta unless they are needed by a store
form.

## Beta Feedback And Launch Candidate Docs

- Feedback master board: `docs/beta_feedback_master_board.md`.
- Severity rubric: `docs/beta_bug_severity_rubric.md`.
- Beta sweep checklist: `docs/beta_sweep_meeting_checklist.md`.
- Launch candidate criteria: `docs/launch_candidate_criteria.md`.
- Beta-to-launch decision tree: `docs/beta_to_launch_decision_tree.md`.
- Feature freeze: `docs/feature_freeze_until_launch.md`.
- Hotfix prompt template: `docs/templates/hotfix_prompt_template.md`.

## Public Launch Submission Docs

- Public launch hard gate: `docs/public_launch_hard_gate.md`.
- Android production checklist:
  `docs/android_production_submission_checklist.md`.
- iOS App Store checklist: `docs/ios_app_store_submission_checklist.md`.
- Store metadata consistency check:
  `docs/store_metadata_final_consistency_check.md`.
- Public announcement drafts: `docs/public_launch_announcement_tr.md`.
- Post-launch monitoring: `docs/post_launch_monitoring_plan.md`.
- Review rejection response template:
  `docs/templates/store_review_rejection_response_template.md`.
- Public launch hotfix policy: `docs/public_launch_hotfix_policy.md`.
