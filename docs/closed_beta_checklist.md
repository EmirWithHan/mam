# Closed Beta Readiness Checklist

Use this before inviting closed beta testers. Check against a staging or beta Supabase project first.

## Auth/Profile

- [ ] Email registration works with friendly Turkish validation.
- [ ] Login works for all demo accounts.
- [ ] Logout returns safely to the auth flow.
- [ ] Profile completion requires the minimum fields.
- [ ] City/district selection uses the centralized Turkey dataset.
- [ ] Profile edit works without exposing raw Supabase errors.
- [ ] Missing avatar, username, full name, bio, city, or district does not crash UI.

## Events

- [ ] Events list loads newest/relevant events without white screen.
- [ ] Empty events state is friendly.
- [ ] Event filters work and can be reset.
- [ ] Event detail loads from list, notification, and deep route.
- [ ] Create event validates title, sport, city/district, date/time, and capacity.
- [ ] Long event titles and locations do not overflow.

## Participation

- [ ] Request to join creates the correct pending state.
- [ ] Pending request can be cancelled.
- [ ] Host can approve a request.
- [ ] Host can reject a request.
- [ ] Approved participant can leave.
- [ ] Full capacity state is clear.
- [ ] Buttons are disabled while actions are running.
- [ ] Chat/call access is available only when intended.

## Feed/Social

- [ ] Feed loads and refreshes.
- [ ] Empty feed state is friendly.
- [ ] Create post works with and without linked event.
- [ ] Likes update locally.
- [ ] Comments load, send, and handle empty state.
- [ ] Follow/unfollow works from feed/profile/list surfaces.
- [ ] Public profile navigation works from safe tappable areas.
- [ ] Report and block actions show friendly Turkish feedback.

## Notifications

- [ ] Notifications list loads newest first.
- [ ] Empty state says there are no notifications.
- [ ] Unread notifications are visually distinct.
- [ ] Tapping event notification marks it read and opens event detail.
- [ ] Tapping profile/follow notification opens public profile when available.
- [ ] Null or missing entity IDs do not crash.
- [ ] Mark all read disables while running and clears unread state.

## Safety/Moderation

- [ ] Report dialog reasons are understandable.
- [ ] Blocked users are hidden from intended surfaces.
- [ ] Users cannot report/block themselves.
- [ ] Demo report content is harmless and clearly fictional.
- [ ] Moderation review process is documented for beta operators.

## Performance

- [ ] Cold start is acceptable on a mid-range Android device.
- [ ] Event list scroll is smooth with demo data.
- [ ] Feed scroll is smooth with demo media.
- [ ] Profile gallery does not load huge images unnecessarily.
- [ ] Pull-to-refresh does not duplicate list items.

## Security/RLS

- [ ] Supabase RLS policies are enabled in beta project.
- [ ] Public profile data comes from safe RPC/service paths.
- [ ] Followers/following lists expose only safe public fields.
- [ ] Private gallery/event data remains gated.
- [ ] Authenticated-only RPCs reject anonymous access.
- [ ] Service role keys are never embedded in the app.

## Mobile Responsiveness

- [ ] Narrow Android viewport has no RenderFlex overflow.
- [ ] iOS safe areas are respected.
- [ ] Chrome/web demo width is usable.
- [ ] Long Turkish names/usernames ellipsize cleanly.
- [ ] Buttons do not touch screen edges.

## Test Accounts

- [ ] Host account is created and documented privately.
- [ ] Approved participant account is created.
- [ ] Pending requester account is created.
- [ ] Rejected requester account is created.
- [ ] Social/feed-heavy account is created.
- [ ] New empty user account is available.
- [ ] Passwords are stored securely outside the repo.

## Known Risks

- [ ] Push notifications are not active.
- [ ] Advanced moderation/admin panel is not active.
- [ ] Analytics are not production-ready.
- [ ] Rate limiting needs backend review before larger rollout.
- [ ] Store assets/signing are not complete.

## Rollback Plan

- [ ] Keep previous app build available.
- [ ] Keep database backup or restore point before demo data changes.
- [ ] Have a staging project separate from production.
- [ ] Document how to disable demo accounts.
- [ ] Document who can pause beta invites.
- [ ] Prepare a short tester communication template for incidents.
