# Match A Man Manual QA Checklist

## Before Testing

- [ ] `flutter analyze` passes locally.
- [ ] `flutter test` passes locally.
- [ ] App runs with dart-define Supabase URL/key.
- [ ] Test users are available.
- [ ] Supabase email confirmation setting is known.
- [ ] Emulator/device internet works.

## Auth

- [ ] Register works.
- [ ] Login works.
- [ ] Logout works.
- [ ] Wrong password shows an error.
- [ ] Session restore opens Events.
- [ ] Logged-out user cannot access protected routes.

## Profile

- [ ] Incomplete profile can browse app.
- [ ] Incomplete profile cannot create event.
- [ ] Incomplete profile cannot request join.
- [ ] Profile completion saves.
- [ ] Avatar upload works.
- [ ] Profile page shows avatar/name/trust score.
- [ ] Settings opens from profile hamburger.
- [ ] Settings logout works.

## Events

- [ ] Events list loads.
- [ ] Empty state works.
- [ ] Create event works.
- [ ] Event detail opens.
- [ ] Capacity displays correctly.
- [ ] Host cannot request own event.
- [ ] Non-host can request to join.
- [ ] Duplicate request does not break app.
- [ ] Full event behavior is acceptable.

## Join Requests

- [ ] Pending state visible.
- [ ] Host sees request.
- [ ] Host approves.
- [ ] Host rejects.
- [ ] Approved participant status visible.
- [ ] Rejected status visible.
- [ ] Participant record created after approval.

## Event Chat

- [ ] Host can open chat.
- [ ] Approved participant can open chat.
- [ ] Pending user cannot access chat.
- [ ] Unrelated user cannot access chat.
- [ ] Send message works.
- [ ] Messages persist after app restart.
- [ ] Social tab shows event chat groups.

## Call Button

- [ ] Approved participant can call host.
- [ ] Host can call approved participant.
- [ ] Pending/unrelated user cannot call.
- [ ] Phone number is not publicly displayed.
- [ ] Call action uses secure flow.

## Feed

- [ ] Create post works.
- [ ] Image upload works.
- [ ] Caption optional.
- [ ] Event association not required.
- [ ] Feed loads posts.
- [ ] Like/unlike works.
- [ ] Comment add works.
- [ ] Post overflow menu works.
- [ ] Self report/block not visible.

## Follow

- [ ] User can follow another user.
- [ ] User can unfollow.
- [ ] User cannot follow self.
- [ ] Follow state persists.

## Reports and Blocks

- [ ] Report post works.
- [ ] Report user works.
- [ ] Report event works.
- [ ] Report comment works.
- [ ] Block user works.
- [ ] Unblock works.
- [ ] Blocked user's posts/events hidden where expected.
- [ ] Own content does not show report/block actions.

## Trust Score

- [ ] Trust score displays.
- [ ] Trust history opens.
- [ ] Empty state works.
- [ ] No client-side score manipulation UI exists.

## UI / UX

- [ ] `#FF7E79` brand color visible.
- [ ] Bottom navigation order correct.
- [ ] No major overflow.
- [ ] Empty states are helpful.
- [ ] Loading/error states are readable.
- [ ] App does not feel like a dating app.
- [ ] Events remain the primary product area.

## Privacy / Safety

- [ ] Phone not visible publicly.
- [ ] Birth date not visible publicly.
- [ ] Public profile previews show only safe fields.
- [ ] Storage images load correctly.
- [ ] Report/block actions accessible but not cluttering UI.

## Known MVP Limitations

- No direct messages yet.
- No realtime chat yet.
- No push notifications yet.
- No map view yet.
- No payment/business panel yet.
- No advanced admin panel yet.
- No algorithmic feed yet.

## Demo Pass Criteria

- [ ] Auth works.
- [ ] Profile completion works.
- [ ] Event create/list/detail works.
- [ ] Join request + approve works.
- [ ] Event chat works.
- [ ] Feed post works.
- [ ] Like/comment works.
- [ ] Report/block does not crash.
- [ ] No obvious private data leakage.
- [ ] No major UI overflow.
