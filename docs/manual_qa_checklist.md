# Manual QA Checklist

Use this checklist for closed beta testers and internal manual regression passes. Record account, device/browser, exact steps, and screenshots/videos for any issue.

## A. Auth

- [ ] Register with email.
- [ ] Log in with email.
- [ ] Log out.
- [ ] Log in with Google.
- [ ] Log in with Facebook.
- [ ] Tap Apple login and confirm it is disabled/Yakında.
- [ ] Confirm no raw Supabase/OAuth error is shown.

## B. Profile

- [ ] username#0000 appears on profile surfaces.
- [ ] Edit profile saves name/full_name.
- [ ] Username input does not require #0000.
- [ ] Uppercase username saves lowercase.
- [ ] Optional fields can be skipped for general browsing.
- [ ] City, district, and birth date can be added for event actions.
- [ ] Missing avatar falls back safely.

## C. Events

- [ ] Browse events.
- [ ] Filter events.
- [ ] Open event detail.
- [ ] Create event.
- [ ] Join/request an event.
- [ ] Host approves a request.
- [ ] Host rejects a request.
- [ ] Approved participant leaves.
- [ ] Past event cannot be joined.
- [ ] Full event shows full-capacity behavior.
- [ ] Missing event-required profile fields show "Profili tamamla."

## D. Social

- [ ] Feed loads.
- [ ] Home/Moments feed loads through `get_visible_feed_posts_with_stats` after DB migrations are pushed.
- [ ] Create a post.
- [ ] Create a photo post without an event link; confirm success is not shown as failed if feed refresh needs retry.
- [ ] Create a photo post with an event link when one is available.
- [ ] Like a post.
- [ ] Comment on a post.
- [ ] Follow a public account.
- [ ] Unfollow an account.
- [ ] Request to follow a private account.
- [ ] Followers list opens.
- [ ] Following list opens.

## E. Privacy

- [ ] Public account content is visible as expected.
- [ ] Private account Gallery is locked for non-followers.
- [ ] Private account Geçmiş Events is locked for non-followers.
- [ ] Approved follower can see allowed private content.
- [ ] Owner can see own private content.
- [ ] Archived gallery item is visible only to owner.

## F. Notifications

- [ ] Event notification appears.
- [ ] Follow notification appears.
- [ ] Follow request notification appears.
- [ ] Approve follow request from notification.
- [ ] Reject follow request from notification.
- [ ] Mark one notification as read.
- [ ] Mark all notifications as read.
- [ ] Empty state says "Henüz bildirimin yok."

## G. Safety

- [ ] Report action is reachable.
- [ ] Block action is reachable.
- [ ] Trust score behavior is understandable if visible.
- [ ] Blocking/reporting does not crash feed, profile, or event screens.

## H. UX And Responsiveness

- [ ] Social login buttons wrap cleanly on narrow screens.
- [ ] Feed like/comment actions do not overflow with long Turkish copy.
- [ ] Repeated taps on like/share/create actions do not create confusing duplicate loading states.
- [ ] Long names, username#0000 handles, captions, comments, and event titles stay readable.
- [ ] Loading, empty, and error states use friendly Turkish copy.

## I. Bug Reporting Format

- Device/browser:
- Account used:
- Exact steps:
- Expected result:
- Actual result:
- Screenshot/video:
- Time of issue:
