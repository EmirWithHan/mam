# Match A Man Demo Release Readiness Checklist

## 1. Current Demo Readiness

- Demo readiness: high, if the manual checklist below passes on the target demo device.
- Closed beta readiness: medium. Core flows are present, but more manual QA, crash monitoring, and moderation operations are still needed.
- Production readiness: not ready yet. App store/legal readiness, production monitoring, moderation workflow, and broader automated test coverage are still missing.

## 2. Must Pass Before Demo

- [ ] App opens without showing default Flutter branding.
- [ ] Auth works for login/logout.
- [ ] Profile completion works.
- [ ] Events opens as the first authenticated page.
- [ ] Create event works.
- [ ] Request, cancel, and re-request join flow works.
- [ ] Host approve/reject works.
- [ ] Event chat works for host/approved participants.
- [ ] Call access is visible only for allowed users.
- [ ] Participant list is visible for host/approved participants.
- [ ] Approved participant can leave event.
- [ ] Capacity count updates after approve/leave.
- [ ] Feed loads without white screen.
- [ ] Create post works.
- [ ] Profile gallery opens and image preview works.
- [ ] My Events section works.
- [ ] Report/block works.
- [ ] No obvious RenderFlex overflow.
- [ ] No terminal red render error during the demo path.

## 3. Demo Test Users

Use at least two prepared accounts.

- Host user: completed profile, avatar, city/district, at least one hosted event, at least one feed post.
- Participant user: completed profile, avatar, city/district, at least one approved event participation, at least one feed post.
- Optional third user: completed profile, avatar, city/district, pending/rejected/unrelated state for comparison.

Each account should have realistic display names, usernames/tags, and clean non-placeholder photos.

## 4. Demo Data Setup

- 1 football event with a strong title, city/district, capacity, and location.
- 1 running, yoga, or swimming event to show variety.
- 3-4 participants across demo events.
- 2-3 feed posts with real images.
- 1 feed post linked to an event.
- Participant list visible on at least one event.
- Trust score example visible in Trust Score history, preferably including event participation behavior.

## 5. Live Demo Flow

1. Open app.
2. Show Events as the authenticated landing page.
3. Open an event detail page.
4. Show capacity, event info, map action, and participant list.
5. Show request, cancel, re-request, and host approval flow using another account if possible.
6. Show chat/call access for host or approved participant.
7. Show Feed and verify posts render normally.
8. Show Create Post with optional linked event.
9. Show Profile Gallery and My Events.
10. Briefly show safety/report/block from an overflow menu.

## 6. Things Not To Demo Yet

- Real push notifications.
- Direct messages.
- Admin panel.
- Payments.
- Business panel.
- Advanced recommendations.
- Production moderation workflow.

## 7. Known Risk Areas

- Public storage buckets are acceptable for avatar/post images, but not for private media.
- Reports need a future moderation/admin workflow.
- Push notifications are not implemented yet.
- Automated test coverage is limited.
- Production analytics/crash reporting is not set up yet.
- App store, privacy policy, terms, and legal readiness are not complete yet.

## 8. Security Checklist

- [ ] RLS enabled on core tables.
- [ ] Direct profile SELECT returns only the current user's own profile.
- [ ] Public profile RPC exposes safe public fields only.
- [ ] Storage upload requires owner/auth identity checks.
- [ ] Sensitive RPCs require authenticated users.
- [ ] Phone and birth date are not public.
- [ ] Event participant list does not expose private fields.
- [ ] Report/block data is not exposed in public UI.
- [ ] Service role keys are not present in the client.

## 9. Final Manual QA Table

| Area | Test | Expected result | Status |
| --- | --- | --- | --- |
| App launch | Open app fresh | Branded MaM app opens cleanly | |
| Auth | Login and logout | Session changes correctly | |
| Profile | Complete/edit profile | Avatar, city, district, and saved fields persist | |
| Events | Open Events tab | Event list loads without layout errors | |
| Create Event | Create valid event | Event appears in list/detail | |
| Join Request | Request, cancel, re-request | State updates correctly each time | |
| Host Review | Approve/reject request | Participant state updates and list refreshes | |
| Participant List | Approved participant opens detail | Katılımcılar section appears with safe fields | |
| Leave Event | Approved participant leaves | Trust warning appears, capacity decreases, chat/call disappear | |
| Capacity | Compare host/participant views | Same approved_count-based capacity is shown | |
| Chat | Host/approved participant opens chat | Chat loads and message send works | |
| Call | Allowed user taps call | Allowed action works or readable error appears | |
| Feed | Scroll feed down/up | No white screen, no disappearing posts | |
| Create Post | Post with and without linked event | Both paths save or show readable error | |
| Profile Gallery | Tap gallery image | Larger image preview opens and closes | |
| My Events | Open profile events tab | Hosted/participated events appear | |
| Safety | Report/block another user/content | Flow opens and completes without crash | |
| Responsive UI | Check small screen path | No major overflow or covered actions | |
| Console | Watch terminal during demo path | No red render/runtime errors | |

## 10. One Hard Recommendation

Before adding new features, spend one focused pass on demo QA and operational safety: run the full manual checklist on the exact demo device, seed reliable demo data, and fix only blockers, crashes, privacy leaks, and confusing state transitions.
