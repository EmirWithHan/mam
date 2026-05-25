# Closed Beta Readiness Checklist

## Auth/Profile

- [ ] Login works with staged test accounts.
- [ ] Register flow creates a Supabase Auth user.
- [ ] Profile completion requires name, username, city, and district.
- [ ] Username validation copy fits on narrow screens.
- [ ] Logout returns safely to the auth flow.
- [ ] No raw Supabase errors are shown to users.

## Public/Private Profile

- [ ] Profiles are public by default.
- [ ] "Gizli hesap" toggle saves and reflects the saved value.
- [ ] Private profile header and counts remain visible to authenticated users.
- [ ] Private gallery is locked for non-followers.
- [ ] Private Geçmiş Events is locked for non-followers.
- [ ] Followers and owners can see allowed private content.

## Follow Requests

- [ ] Public account follow works immediately.
- [ ] Public account follow creates a "Yeni takipçi" notification.
- [ ] Private account follow creates a pending request, not an immediate follow.
- [ ] Private profile button changes to "İstek Gönderildi".
- [ ] Pending request does not unlock gallery or Geçmiş Events.
- [ ] Private user receives a follow request notification.
- [ ] "Onayla" creates the follow relationship.
- [ ] "Reddet" does not create the follow relationship.
- [ ] Approved requester can see private gallery and Geçmiş Events after refresh.

## Followers/Following

- [ ] Own followers list opens.
- [ ] Own following list opens.
- [ ] Public profile followers list opens.
- [ ] Public profile following list opens.
- [ ] Private profile followers/following lists follow intended basic-profile visibility.
- [ ] Empty followers state says "Henüz takipçi yok."
- [ ] Empty following state says "Henüz kimse takip edilmiyor."
- [ ] Row tap opens public profile safely.

## Gallery

- [ ] Own gallery loads.
- [ ] Public gallery loads when allowed.
- [ ] Private gallery shows locked state when not allowed.
- [ ] Gallery viewer opens and closes safely.
- [ ] Owner three-dot menu appears only for owner.
- [ ] Archived item is visible to owner with lock overlay.
- [ ] Archived item is hidden from other users.
- [ ] Delete action asks for confirmation.

## Events

- [ ] Events list loads.
- [ ] Event filters work.
- [ ] Create event validates required fields.
- [ ] Event detail opens from event list and notifications.
- [ ] Host profile navigation from event detail works.
- [ ] Past events are viewable but not joinable.
- [ ] Active Events appear above Geçmiş Events in profiles.

## Participation

- [ ] User can request to join a future event.
- [ ] User can cancel a pending request.
- [ ] Host can approve a request.
- [ ] Host can reject a request.
- [ ] Approved participant can leave.
- [ ] Full capacity state is clear.
- [ ] Buttons disable while actions are running.
- [ ] Chat/call access gating matches participation state.

## Feed/Social

- [ ] Feed loads without false error states.
- [ ] Create post works.
- [ ] Event-linked post opens event detail.
- [ ] Likes update locally.
- [ ] Comments handle long text.
- [ ] Follow/unfollow works from supported surfaces.
- [ ] Private follow request state is clear from supported follow buttons.
- [ ] Own post delete works.
- [ ] Report/block controls are reachable and safe.

## Notifications

- [ ] Notifications list loads newest first.
- [ ] Unread/read visual states are clear.
- [ ] Tapping event notification opens event detail.
- [ ] Tapping profile/follow notification opens profile when available.
- [ ] Follow request notification shows "Onayla" and "Reddet".
- [ ] Approve/reject actions disable while loading.
- [ ] Mark one read works.
- [ ] Mark all read works and disables during loading.
- [ ] Empty state says "Henüz bildirimin yok."

## Safety/Moderation

- [ ] Report flow does not crash.
- [ ] Block flow does not crash.
- [ ] Blocked/reported content behavior is understood by the demo team.
- [ ] No private media or archived items leak to unauthorized users.
- [ ] Participant visibility rules are preserved.

## Performance

- [ ] Cold start is acceptable on demo devices.
- [ ] Feed scroll is smooth enough for closed beta.
- [ ] Event list scroll is smooth enough for closed beta.
- [ ] Profile gallery does not overflow or freeze.
- [ ] Large text and missing images do not cause layout errors.

## Security/RLS

- [ ] Supabase RLS policies are reviewed before beta.
- [ ] Safe RPCs are used for public profile, gallery, event history, followers, following, and follow requests.
- [ ] No broad direct profile SELECT was added for public data.
- [ ] Service role keys are not present in the client.
- [ ] `.env` files are not committed.

## Mobile Responsiveness

- [ ] Narrow Android layout checked.
- [ ] Narrow iPhone layout checked.
- [ ] Chrome/web layout checked if used for demo.
- [ ] Long Turkish names and usernames do not overflow.
- [ ] Buttons have safe spacing near screen edges.

## Test Accounts

- [ ] Host user prepared.
- [ ] Approved participant prepared.
- [ ] Pending event requester prepared.
- [ ] Rejected event requester prepared.
- [ ] Social/feed-heavy user prepared.
- [ ] Private profile user prepared.
- [ ] Follow request requester prepared.
- [ ] New empty user prepared.
- [ ] Passwords are stored outside the repository.

## Known Risks

- [ ] Remote Supabase migrations are confirmed applied.
- [ ] Demo data can be reset if a walkthrough changes state.
- [ ] Network failure behavior is acceptable.
- [ ] Push/realtime expectations are clearly positioned as postponed.
- [ ] Abuse/rate limiting limits are understood before inviting testers.

## Rollback Plan

- [ ] Keep a known-good app build available.
- [ ] Keep a known-good Supabase migration state documented.
- [ ] Prepare a short "demo reset" procedure for test accounts.
- [ ] Assign one owner for beta issue triage.
- [ ] Pause invites if auth, event joins, follow requests, profile privacy, or notifications regress.
