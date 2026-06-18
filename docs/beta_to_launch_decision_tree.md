# Beta To Launch Decision Tree

1. Are there any BLOCKER bugs?
   - Yes: stop launch, create hotfix prompt.
   - No: continue.

2. Are there HIGH bugs in auth/onboarding/main navigation?
   - Yes: fix before wider beta/store.
   - No: continue.

3. Are privacy/account deletion/store metadata ready?
   - No: finish legal/store docs before public submission.
   - Yes: continue.

4. Did Android closed test pass minimum tester period/requirements?
   - No: continue closed test.
   - Yes: Android can move toward production.

5. Did iOS TestFlight internal/external beta pass smoke test?
   - No: continue TestFlight fixes.
   - Yes: iOS can move toward App Store review.

6. Are Android and iOS equally ready?
   - Yes: synchronized launch.
   - No: keep stronger platform in beta/soft launch or submit separately after
     user decision.

7. Does `docs/public_launch_hard_gate.md` pass?
   - No: stop public submission and list blockers.
   - Yes: use platform production/App Store checklists.

8. Is post-launch monitoring ready?
   - No: prepare `docs/post_launch_monitoring_plan.md`.
   - Yes: submit/release according to platform review status.
