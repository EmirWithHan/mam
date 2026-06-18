# Play Closed Test Pre-Submission Gate

Do not proceed to Play Console upload unless every BLOCKER item is marked yes.

Related launch planning:

- Master timeline: `docs/master_launch_timeline.md`.
- Critical path checklist: `docs/critical_path_checklist.md`.
- Prompt status board: `docs/prompt_status_board.md`.
- Manual decision guide: `docs/manual_decision_guide.md`.
- Next actions checklist: `docs/next_actions_checklist.md`.

## BLOCKER

- [ ] Android app opens on a real device.
- [ ] Email/password signup immediately shows `E-postanı doğrula` after
  registration.
- [ ] Verification email arrives.
- [ ] Verified user can continue to username onboarding.
- [ ] Username onboarding works.
- [ ] Home opens.
- [ ] Events opens.
- [ ] Profile opens.
- [ ] Settings opens.
- [ ] App icon is Match A Man, not the Flutter logo.
- [ ] Normal flows do not show raw Supabase/Postgrest errors.
- [ ] Signed AAB can be built.
- [ ] No real secrets are committed.
- [ ] Privacy policy URL is ready or documented as a blocker.
- [ ] Account deletion web URL is ready or documented as a blocker.
- [ ] Reviewer test account plan exists.

## HIGH

- [ ] Screenshots are ready.
- [ ] Store listing draft is ready.
- [ ] Data Safety draft is ready.
- [ ] Content rating answers are prepared.
- [ ] App access instructions are prepared.
- [ ] Tester list is collected privately.

## MEDIUM

- [ ] Feature graphic is ready.
- [ ] Final polish copy is reviewed.
- [ ] Extra tester docs are ready.

## Decision

Proceed only when all BLOCKER items are yes and HIGH items are either complete
or explicitly accepted for closed testing.
