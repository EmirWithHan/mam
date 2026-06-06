# Manual QA Checklist

Use this checklist for closed beta testers and internal regression passes. Record account, device, exact steps, and screenshots/videos for any issue.

## Auth

- [ ] Register with email.
- [ ] Log in with email.
- [ ] Log out.
- [ ] Restore an existing session after app restart.
- [ ] Complete profile bootstrap after signup/OAuth.
- [ ] Complete required profile fields.
- [ ] Google/Facebook buttons do not crash.
- [ ] Apple login remains disabled/coming soon unless developer setup exists.
- [ ] No route loop, stuck auth loading, or raw Supabase/OAuth error.

## Feed

- [ ] Feed loads.
- [ ] Empty feed state works.
- [ ] Pull to refresh reloads from the first page.
- [ ] Pagination appends without duplicates.
- [ ] Text and photo post cards fit on small screens.
- [ ] Username/business identity display is correct.
- [ ] Follow/search interactions do not break feed state.
- [ ] Tab switching does not cause a white screen.
- [ ] Infinite scroll does not crash.
- [ ] Errors use friendly copy, not `PostgrestException`.

## Post Creation

- [ ] Create text/photo post.
- [ ] Upload validation blocks invalid input.
- [ ] Event-linked post works when supported.
- [ ] Delete/report post works when available.
- [ ] Local feed refreshes after create/delete.
- [ ] Double submit does not create confusing duplicate loading states.

## Events

- [ ] Event list loads and paginates.
- [ ] Event card fits at 320 px width.
- [ ] Event detail opens.
- [ ] Create normal event.
- [ ] Create business event only from approved business account.
- [ ] Join request works.
- [ ] Host approve/reject works.
- [ ] Participant leave works.
- [ ] Past event behavior is correct.
- [ ] Capacity display is correct.
- [ ] Location button opens maps or shows a friendly error.
- [ ] No infinite-width button or RenderFlex overflow.

## Business Lifecycle

- [ ] User sees "Isletme hesabi basvurusu yap".
- [ ] Application submit works.
- [ ] Duplicate pending application is blocked.
- [ ] Admin approve works.
- [ ] Admin reject works.
- [ ] Approved application upgrades the same profile to business.
- [ ] No second public business profile is created.
- [ ] Business event creation works.
- [ ] "Isletme hesabimi sil" works.
- [ ] Business delete returns to user mode.
- [ ] Future business events are hidden/cancelled after delete.
- [ ] Sponsored flags are ignored after delete.
- [ ] Deleted business is not public/sponsored.
- [ ] Normal client cannot edit moderation fields directly.

## Username Search And Add Friend

- [ ] Search page opens from Social/Profile/Settings entry point.
- [ ] Search does not run before 2 characters.
- [ ] Debounce prevents a request on every rebuild/keystroke.
- [ ] Search by username works.
- [ ] Search by username#0000 works.
- [ ] Self result shows "Sen" and disables action.
- [ ] Public user follow/add friend works.
- [ ] Private user request works.
- [ ] Already following/pending labels are correct.
- [ ] Tapping a result opens the canonical profile route.
- [ ] Phone/email are not exposed in results.

## Profile

- [ ] Own profile loads.
- [ ] Public profile loads.
- [ ] Private profile locks gallery/events for non-followers.
- [ ] Approved followers can see allowed private content.
- [ ] Business profile mode displays correctly.
- [ ] Followers/following lists open.
- [ ] Gallery grid fits.
- [ ] Settings navigation works.
- [ ] Avatar/name/username layout fits with long text.

## Social And Chat

- [ ] Social page loads.
- [ ] Event chat list loads if present.
- [ ] Chat opens.
- [ ] Message input stays visible above keyboard.
- [ ] Long messages wrap cleanly.
- [ ] Empty chat state works.

## Notifications

- [ ] Notifications list loads.
- [ ] Empty state works.
- [ ] Pagination/limit works.
- [ ] Notification badge/count updates while the app is open.
- [ ] Notifications list refreshes while the page is open after a new notification.
- [ ] Mark one notification as read.
- [ ] Mark all notifications as read.
- [ ] Notification tap navigation does not crash.
- [ ] Approve/reject follow request from notification.

## Feedback

- [ ] Settings > "Geri bildirim gonder" opens.
- [ ] Rating 1-5 validation works.
- [ ] Empty message is allowed when rating/category exists.
- [ ] Message max length is enforced.
- [ ] Feedback submit works.
- [ ] Friendly error appears on failure.
- [ ] No forced store review or manipulative gating.

## Legal And Language

- [ ] Main visible UI copy is Turkish; no user-facing "event/feed/post/comment/profile/settings/business/admin" wording remains.
- [ ] Kullanım Şartları page opens and has detailed MVP draft text.
- [ ] Gizlilik Politikası page opens.
- [ ] Topluluk Kuralları page opens.
- [ ] Etkinlik Güvenliği ve Sorumluluk Reddi page opens.
- [ ] `docs/legal_todo.md` legal-review warning is still present.

## Admin

- [ ] Non-admin cannot access admin.
- [ ] Admin can access admin.
- [ ] Application list is limited/paginated.
- [ ] Approve/reject buttons disable while loading.
- [ ] Feedback list appears if available.
- [ ] Admin layout fits on mobile width.

## Responsive Devices

Test each device/viewport:

- [ ] 320x568 small phone.
- [ ] 360x640 common Android.
- [ ] 390x844 iPhone-like.
- [ ] 412x915 large Android.
- [ ] 600x960 small tablet.
- [ ] Landscape mobile if supported.

For each device:

- [ ] No yellow/black overflow stripes.
- [ ] No clipped primary button.
- [ ] No hidden text input behind keyboard.
- [ ] No infinite-width exception.
- [ ] No white screen.
- [ ] Long names, username#0000 handles, captions, comments, event titles, chips, and buttons stay readable or ellipsized.

## Rate And Cost Guardrails

- [ ] Refresh resets pagination.
- [ ] Pagination does not duplicate items.
- [ ] In-app realtime refresh does not repeatedly reload on every rebuild.
- [ ] Leaving notification/comment/admin pages does not leave duplicate subscriptions.
- [ ] Spam actions show "Cok fazla islem yaptin. Biraz sonra tekrar dene." if rate limits are configured.
- [ ] Obvious services do not use unlimited selects.
- [ ] Profile/search/feed screens do not refetch repeatedly on every rebuild.

## Test TODOs

- [ ] Add deeper widget tests for search result cards once provider/router dependencies are easier to mock.
- [ ] Add keyboard-overlay widget tests for forms once app-level test harness supports constrained viewInsets.

## Bug Reporting Format

- Device/browser:
- Account used:
- Exact steps:
- Expected result:
- Actual result:
- Screenshot/video:
- Time of issue:
