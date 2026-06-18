# Prompt Status Board

| Prompt | Purpose | Status | Can run now? | Depends on | Output | Blocker if not done? |
| --- | --- | --- | --- | --- | --- | --- |
| 172B Fix email confirmation pending screen | Ensure signup immediately shows `E-postanı doğrula` and blocks unverified users from main shell. | Completed or verify on device | Yes, as verification/sweep | Supabase email confirmation enabled | Auth confirmation UX fixed | Yes, before APK beta |
| 173 Android Signed AAB + Play Console Upload Prep | Prepare signed Android release AAB flow and Play upload inputs. | Prep docs exist; upload still manual | Yes | APK beta blockers resolved, local keystore private | Signed AAB plan and commands | Yes, before Play closed test |
| 174 Play Console Closed Test Submission Pack | Prepare Play Console forms, tester operations, release notes, and private values checklist. | Prep docs exist | Yes | Play Console account/app setup | Closed test submission pack | Yes, before Play closed test |
| 175 iOS MacInCloud Build Day + TestFlight Prep | Prepare Apple Developer, MacInCloud, signing, metadata, and TestFlight docs. | Prep docs exist | Yes | Apple Developer not required for docs | iOS build day prep pack | Yes, before MacInCloud/TestFlight |
| 176 Android + iOS Simultaneous Launch Master Plan | Combine Android and iOS into one launch execution timeline. | In progress in this doc set | Yes | Prior prep docs | Master timeline and checklists | Yes, for coordination |
| 177 Final APK beta bug sweep | One last Android real-device sweep before sending APK to friends. | Future optional | Yes after latest APK build | 172B verified on device | Final APK beta readiness result | Yes, before wider APK beta |
| 178 Signed AAB build and Play upload day | Build signed AAB and guide manual Play Console upload. | Future optional | After keystore/store inputs ready | Play Console app, signing, URLs | Closed test upload result | Yes, before Play closed test |
| 179 MacInCloud iOS build day support | Guide live MacInCloud signing, IPA build, and TestFlight upload. | Future optional | After Apple Developer active | Apple Developer, ASC, runbook | TestFlight upload or exact blocker | Yes, before iOS beta |
| 180 Android+iOS beta feedback sweep | Triage and fix beta feedback from both tracks. | Prepared | Yes | Android APK/closed test and TestFlight feedback | Feedback board, severity rubric, launch criteria, decision tree | Yes, before public launch |
| 181 Public launch submission pack | Final public store submission checklist, launch gate, announcement, monitoring, and hotfix policy. | Prepared | After beta blockers resolved | Beta feedback sweep + launch candidate | Production submission pack | Yes, before public launch |

## Current Direction

Move Android APK beta first, then Play closed testing, while Apple Developer and
iOS signing prep catch up. Do not rent MacInCloud until Apple Developer and App
Store Connect access are confirmed.

Use `docs/beta_feedback_master_board.md` and
`docs/beta_bug_severity_rubric.md` during both Android and iOS beta testing.
Feature requests stay deferred by `docs/feature_freeze_until_launch.md` unless
they directly fix a blocker.

Public production/App Store submission must use
`docs/public_launch_hard_gate.md` and the platform submission checklists before
any upload or review submission.
