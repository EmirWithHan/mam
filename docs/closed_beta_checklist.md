# Closed Beta Readiness Checklist

## Auth/Profile

- [ ] Email register works.
- [ ] Email login works.
- [ ] Logout returns to auth flow safely.
- [ ] Auth state restores after refresh/reopen.
- [ ] Core profile requires username and name/full_name only.
- [ ] username#0000 display appears on profile surfaces.
- [ ] Uppercase username input saves lowercase.
- [ ] Duplicate username shows friendly Turkish copy.
- [ ] No surname/last_name is required.

## Social Login

- [ ] Google login starts Supabase OAuth.
- [ ] Facebook login starts Supabase OAuth.
- [ ] OAuth callback route returns users safely to the app.
- [ ] Social signup creates username, name/full_name, and 4-digit tag.
- [ ] Optional fields do not block social users from browsing.
- [ ] Apple is disabled or clearly marked Yakında.

## Public/Private Profile

- [ ] Public profiles show allowed content.
- [ ] Private profiles hide Gallery from non-followers.
- [ ] Private profiles hide Geçmiş Events from non-followers.
- [ ] Owner always sees own private content.
- [ ] Followers can see allowed private content.
- [ ] Locked copy says: "Bu alanı görmek için kullanıcıyı takip etmelisin."

## Follow Requests

- [ ] Public account follow is instant.
- [ ] Private account follow creates a request, not a follow.
- [ ] Pending request state is visible.
- [ ] Approve creates the follow relationship.
- [ ] Reject does not create the follow relationship.
- [ ] Pending request does not reveal private content.

## Followers/Following

- [ ] Followers list loads.
- [ ] Following list loads.
- [ ] Empty followers state is friendly.
- [ ] Empty following state is friendly.
- [ ] Self follow button never appears.
- [ ] Row tap opens the correct public profile.

## Gallery

- [ ] Own gallery loads.
- [ ] Public gallery loads when allowed.
- [ ] Private gallery shows locked state when not allowed.
- [ ] Owner menu appears only for owner.
- [ ] Archive/unarchive works.
- [ ] Archived items are visible only to owner.
- [ ] Delete confirmation works.
- [ ] Gallery viewer back navigation works.

## Events

- [ ] Events list loads.
- [ ] Event filters work.
- [ ] Event detail opens.
- [ ] Create event validates required fields.
- [ ] Past events are viewable but not joinable.
- [ ] Full events show full-capacity behavior.
- [ ] Host profile opens from event detail.

## Event-Required Profile Fields

- [ ] Home loads without city/district/birth date.
- [ ] Feed loads without city/district/birth date.
- [ ] Events browsing loads without city/district/birth date.
- [ ] Event detail loads without city/district/birth date.
- [ ] Join/create event requires city, district, and birth date.
- [ ] "Profili tamamla" opens profile completion/edit.
- [ ] Saving required fields returns safely to the intended flow.

## Participation

- [ ] Request to join works.
- [ ] Cancel pending request works.
- [ ] Host approve works.
- [ ] Host reject works.
- [ ] Approved participant leave works.
- [ ] Buttons disable while actions are loading.
- [ ] Participant list visibility matches access rules.
- [ ] Event notifications are created/displayed where expected.

## Feed/Social

- [ ] Feed loads without false error states.
- [ ] Empty feed state is clear.
- [ ] Create post works.
- [ ] Likes work.
- [ ] Comments work.
- [ ] Long captions/comments wrap.
- [ ] Missing images/avatars fall back safely.
- [ ] Private or archived content does not leak.

## Notifications

- [ ] Notifications page loads.
- [ ] Empty state says: "Henüz bildirimin yok."
- [ ] Error state says: "Bildirimler yüklenemedi."
- [ ] Event notification opens event detail.
- [ ] Follow notification opens profile safely.
- [ ] Follow request notification shows Onayla/Reddet.
- [ ] Mark read works.
- [ ] Mark all read works.

## Safety/Moderation

- [ ] Report action is reachable.
- [ ] Block action is reachable.
- [ ] Blocked/reported users do not create unsafe UI states.
- [ ] Trust score display, if visible, is understandable.
- [ ] No harmful real demo content is used.

## Performance

- [ ] App starts quickly on test devices.
- [ ] Feed and events list scrolling are smooth enough for beta.
- [ ] Large images do not crash common screens.
- [ ] Loading states do not get stuck after actions.

## Security/RLS

- [ ] No secrets are stored in docs or source.
- [ ] Private profile data is not visible to unauthorized users.
- [ ] Archived gallery items are hidden from others.
- [ ] Event participant data follows intended visibility rules.
- [ ] RLS policies are reviewed before public beta.

## Mobile Responsiveness

- [ ] Narrow mobile widths do not overflow.
- [ ] Web/Chrome demo width looks acceptable.
- [ ] Long names and username#0000 handles fit.
- [ ] Keyboard open/close does not block key actions.
- [ ] Primary buttons do not touch screen edges.

## Test Accounts

- [ ] Host account prepared.
- [ ] Approved participant prepared.
- [ ] Pending requester prepared.
- [ ] Rejected requester prepared.
- [ ] Private profile account prepared.
- [ ] Follow request requester prepared.
- [ ] New empty user prepared.
- [ ] Safety/report demo user prepared.

## Known Risks

- [ ] Push notifications are postponed.
- [ ] Realtime notifications are postponed.
- [ ] Apple login is postponed.
- [ ] Advanced moderation is postponed.
- [ ] Store assets are not final.
- [ ] Production analytics are not active.

## Rollback Plan

- [ ] Keep beta cohort small.
- [ ] Preserve known-good staging data snapshot where possible.
- [ ] Document reproduction steps for critical bugs.
- [ ] Disable beta invites if auth, privacy, or event participation breaks.
- [ ] Communicate postponed features clearly to testers.
