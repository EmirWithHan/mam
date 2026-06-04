# Final Manual QA Script

Use this script for the final MVP pass before closed beta or store pre-launch review. Record device, build, account, exact steps, screenshots/videos, and Supabase project used for every run.

## Global Checks

Run every flow with these failure signs in mind:

- No yellow/black overflow stripes.
- No clipped buttons or unreadable labels.
- Keyboard does not hide active form fields or submit buttons.
- No white screen, route loop, frozen loader, or infinite-width error.
- No raw `PostgrestException`, `PGRST`, SQLSTATE, stack trace, or database policy text shown to users.
- Loading buttons disable duplicate submit.
- Empty states and error states use friendly copy.

## Test Accounts

- New user A: fresh email, no profile.
- Existing user A: completed user profile.
- Existing user B: completed user profile.
- Private user C: completed profile with private account enabled.
- Host user H: completed profile, owns a test event.
- Business applicant BA: normal user with no active business.
- Business owner BO: approved active business account.
- Admin user AD: user present in `admin_users`.
- Non-admin user NA: normal user not present in `admin_users`.

## Responsive Matrix

Repeat core navigation, auth, forms, event detail, profile, settings, and create flows on:

- 320x568
- 360x640
- 390x844
- 412x915
- 600x960

For each size:

- Steps: open app, visit Home, Events, Create, Social, Profile, Settings, and at least one form with keyboard open.
- Expected result: content scrolls, primary actions remain reachable, text wraps or truncates cleanly, and no overflow/white screen appears.
- Common failure signs: RenderFlex overflow, infinite width exception, clipped bottom button, hidden keyboard field, stuck loader, blank route.

## 1. Fresh Install / First Open

Test account needed: none.

Steps:

1. Install a fresh debug/release build.
2. Open the app with no existing session.
3. Observe splash and auth landing.
4. Rotate only if the target platform supports it.

Expected result:

- Match A Man branding appears.
- No debug banner.
- User lands on auth flow.
- No permissions are requested immediately.

Common failure signs:

- White screen after splash.
- App asks for location/photos before user action.
- Old `MaM` or Flutter template text appears in native shell.
- Raw Supabase/env error shown instead of friendly setup error.

## 2. Register

Test account needed: new user A.

Steps:

1. Open Register.
2. Enter valid email and password.
3. Submit.
4. Complete any email verification expectation for the configured Supabase project.

Expected result:

- Registration succeeds or shows clear email verification guidance.
- App routes to profile completion when authenticated.
- Duplicate/invalid email errors are friendly.

Common failure signs:

- Raw auth exception.
- Register button can be double tapped into duplicate loading.
- Route loop between auth/profile completion.

## 3. Login

Test account needed: existing user A.

Steps:

1. Open Login.
2. Enter valid email and password.
3. Submit.
4. Repeat with invalid password.

Expected result:

- Valid login restores the app to Events/Home based on profile state.
- Invalid login shows friendly error.
- Password field and submit remain visible with keyboard open.

Common failure signs:

- Raw `invalid login credentials` technical text.
- Stuck auth loading.
- Keyboard hides submit on 320x568.

## 4. Profile Completion

Test account needed: new user A or incomplete existing user.

Steps:

1. Land on profile completion.
2. Enter username and name.
3. Save.
4. Reopen profile completion in event-requirements mode by attempting an event action that needs city, district, and birth date.
5. Add city, district, birth date, optional phone, optional avatar.

Expected result:

- Core profile lets user enter app.
- Event-required fields are enforced only for event actions.
- Avatar picker requests photo permission only after tap.
- Phone validation is friendly.

Common failure signs:

- Profile save exposes duplicate key/Postgrest text.
- Avatar upload failure crashes.
- City/district sheet overflows.

## 5. Home / Feed

Test account needed: existing user A.

Steps:

1. Open Home.
2. Pull to refresh.
3. Scroll to pagination threshold.
4. Open a post profile/event link if visible.

Expected result:

- Feed loads, empty state is valid, pagination does not duplicate.
- Blocked users are hidden.
- Feed cards fit all responsive sizes.

Common failure signs:

- Infinite loader on empty feed.
- Duplicate posts after refresh/pagination.
- Phone/email/private fields visible in feed.

## 6. Create Post

Test account needed: existing user A with completed profile.

Steps:

1. Open Create > Post.
2. Try submit without photo.
3. Pick a gallery image.
4. Add valid caption.
5. Optionally link an eligible event.
6. Submit.

Expected result:

- Missing photo is blocked with friendly message.
- Photo permission appears only after picker tap.
- Submit creates one post and returns to feed/home.

Common failure signs:

- Gallery permission copy missing on iOS.
- Duplicate submit creates multiple posts.
- Upload error shows storage/Postgrest internals.

## 7. Events List

Test account needed: existing user A.

Steps:

1. Open Events tab.
2. Pull to refresh.
3. Scroll through event cards.
4. Open an event detail.

Expected result:

- Active/completed visible events load.
- Cards fit small screens.
- Sponsored/business labels do not expose moderation-only fields.

Common failure signs:

- Event card overflow.
- Deleted business event still promoted as sponsored.
- Raw query/RLS error on list.

## 8. Create Event

Test account needed: existing user A with event-ready profile.

Steps:

1. Open Create > Event.
2. Submit empty form.
3. Fill sport, title, city, district, date, capacity, and location text.
4. Tap location helper if testing device permissions.
5. Submit.

Expected result:

- Validation catches missing fields.
- Location permission is requested only after user taps location action.
- Event appears in Events.

Common failure signs:

- Keyboard hides submit.
- Location denial crashes.
- User can create business/paid event without active business.

## 9. Join Event

Test account needed: existing user B, event owned by host H.

Steps:

1. Login as user B.
2. Open host H event.
3. Tap join/request button.
4. Refresh detail.

Expected result:

- Join request is created.
- Button state changes to pending/current state.
- Past/full/profile-incomplete cases show friendly blockers.

Common failure signs:

- Duplicate request on double tap.
- Raw `event_full`, policy, or RPC error.
- Pending state not shown after refresh.

## 10. Approve / Reject Participant

Test account needed: host H with pending request from user B.

Steps:

1. Login as host H.
2. Open hosted event detail.
3. Approve a pending request.
4. Create another request and reject it.
5. Refresh event detail.

Expected result:

- Approve/reject buttons disable while loading.
- Approved participant count/status updates.
- Rejected user is not shown as active participant.

Common failure signs:

- Normal participant can review requests.
- Duplicate tap changes state twice.
- Raw RPC/Postgrest error.

## 11. Leave Event

Test account needed: user B approved in an event.

Steps:

1. Login as user B.
2. Open approved event detail.
3. Tap leave/cancel participation action.
4. Confirm if prompted.
5. Refresh event.

Expected result:

- User leaves approved event.
- Participant count/status updates.
- Trust-score side effect does not block the user flow if it fails.

Common failure signs:

- Leave action visible to wrong status.
- Event detail crashes after leaving.
- Raw trust-score/RPC error.

## 12. Username Search

Test account needed: existing user A and user B.

Steps:

1. Open Social > Search.
2. Type one character.
3. Type at least two characters.
4. Search by username and username#tag.
5. Tap a result.

Expected result:

- Search does not run before minimum length.
- Results show public-safe profile fields.
- Result tap opens canonical public profile.

Common failure signs:

- Email, phone, auth metadata, admin fields, or private moderation fields visible.
- Request fires on every rebuild.
- Raw search RPC error.

## 13. Add Friend / Follow

Test account needed: user A and public user B.

Steps:

1. Login as user A.
2. Search user B.
3. Tap follow/add action.
4. Reopen search/profile.

Expected result:

- Public follow succeeds.
- Label changes to following/already following.
- Self result is disabled.

Common failure signs:

- Self-follow allowed.
- Duplicate follow rows from double tap.
- State does not update after action.

## 14. Private Follow Request

Test account needed: user A and private user C.

Steps:

1. Login as user A.
2. Search private user C.
3. Send follow request.
4. Login as user C.
5. Open notifications and approve/reject request.

Expected result:

- Request state is pending for user A.
- Private user receives notification.
- Approve/reject updates notification state and follow relationship.

Common failure signs:

- Private content visible before approval.
- Follow request notification opens wrong route.
- Raw policy/RPC error.

## 15. Profile View

Test account needed: user A, public user B, private user C.

Steps:

1. Open own profile.
2. Open public profile for user B.
3. Open private profile for user C as non-follower.
4. Open private profile as approved follower.
5. Open followers/following and gallery items.

Expected result:

- Own profile shows editable/self state.
- Public profile shows allowed public fields.
- Private profile locks gallery/events for non-followers.
- Long usernames/names fit.

Common failure signs:

- Phone/email visible on public profile.
- Gallery grid overflows.
- Fallback names look like test placeholders.

## 16. Settings

Test account needed: existing user A.

Steps:

1. Open Settings from Profile.
2. Toggle privacy.
3. Open feedback.
4. Open legal/support links.
5. Open blocked users.
6. Logout only after session-restore test is ready.

Expected result:

- Settings options open.
- Legal pages clearly say MVP draft where applicable.
- Admin link is hidden for non-admin users.

Common failure signs:

- Test/admin button visible to normal user.
- Legal/support routes white screen.
- Privacy toggle exposes raw error.

## 17. Business Application

Test account needed: business applicant BA.

Steps:

1. Login as BA.
2. Open Settings > business application.
3. Submit empty form.
4. Submit valid business name, phone, address, category, optional website/description.
5. Try submitting a duplicate pending application.

Expected result:

- Validation catches missing/invalid fields.
- Valid application enters pending state.
- Duplicate pending application is blocked with friendly copy.

Common failure signs:

- Invalid phone accepted.
- Raw unique/policy error.
- User can set `is_verified`, `status`, or sponsored fields.

## 18. Admin Approve / Reject

Test account needed: admin AD and non-admin NA.

Steps:

1. Login as NA and try `/admin`.
2. Login as AD and open Settings > Admin.
3. Review pending applications.
4. Approve one application.
5. Reject another application with note.

Expected result:

- Non-admin sees admin-required message and cannot load admin data.
- Admin list loads and paginates.
- Approve/reject buttons disable while loading.
- Approved user becomes active business account.

Common failure signs:

- Non-admin can see application details.
- Admin list leaks feedback/application data to normal user.
- Raw `not_admin` or RPC error.

## 19. Business Event

Test account needed: business owner BO.

Steps:

1. Login as BO.
2. Create a business event.
3. Set business-specific fields such as paid/free if available.
4. Open event detail as another user.
5. Request/join and confirm business participation if required.

Expected result:

- Only active business owner can create business event.
- Business identity displays correctly.
- Deleted/unverified business does not appear as sponsored.

Common failure signs:

- Normal user creates paid/business event.
- Deleted business appears publicly.
- Business attendance flow crashes.

## 20. Business Delete

Test account needed: business owner BO.

Steps:

1. Login as BO.
2. Open Settings.
3. Use business delete/passivation action.
4. Confirm.
5. Return to profile and Events.

Expected result:

- Profile returns to user mode.
- Future business events are cancelled/hidden.
- Sponsored flags are cleared.
- User account remains usable.

Common failure signs:

- Deleted business still public/sponsored.
- Business delete affects another account.
- Profile crashes because business account is null.

## 21. Feedback Form

Test account needed: existing user A.

Steps:

1. Open Settings > Feedback.
2. Submit with invalid/missing required values.
3. Submit valid rating/category/message.
4. Repeat quickly to test rate limit behavior.

Expected result:

- Validation works.
- Submit succeeds with thank-you message.
- Rate limit uses friendly copy.

Common failure signs:

- Raw database/rate-limit token shown.
- Button allows duplicate submit.
- Feedback page overflows with keyboard.

## 22. Report / Block

Test account needed: user A and target user B/content.

Steps:

1. Open a public profile, post, comment, or event with report action.
2. Submit a report reason.
3. Block target user where block action is available.
4. Reopen feed/events/profile/search.
5. Unblock from Settings > blocked users.

Expected result:

- Report submits or shows clear TODO if a specific target type is not wired.
- Blocked user/content is hidden where implemented.
- Blocked users page lists and removes blocks.

Common failure signs:

- Report form exposes moderation-only fields.
- Block yourself is allowed.
- Raw RLS/report insert error.

## 23. Notifications

Test account needed: users A/B/C and host H.

Steps:

1. Trigger follow request, join request, and approval/rejection notifications.
2. Open Notifications.
3. Tap notification rows.
4. Mark one as read.
5. Mark all as read.
6. Approve/reject follow request from notification.

Expected result:

- Notifications load and navigate safely.
- Read state updates.
- Empty state is valid.

Common failure signs:

- Notification opens blank page.
- Request action remains pending after approve/reject.
- Raw metadata/RPC error.

## 24. Logout / Session Restore

Test account needed: existing user A.

Steps:

1. Login.
2. Kill/restart app.
3. Confirm session restores.
4. Logout from Settings.
5. Kill/restart app again.

Expected result:

- Logged-in session restores without auth loop.
- Logout returns to auth and stays logged out.
- Profile-completion state is respected.

Common failure signs:

- Splash never exits.
- Logged-out user can access protected routes.
- Auth callback route loops.

## 25. Responsive Check

Test account needed: existing user A, plus host/business/admin where needed.

Steps:

1. Run the responsive matrix listed above.
2. At each size, test auth, profile completion, feed, create post, create event, event detail, search, settings, business application, admin list, and feedback.
3. Open keyboard in every form.
4. Use long text values for event title, username, name, comments, and business name.

Expected result:

- All layouts remain usable.
- Buttons remain reachable.
- Text fields scroll above keyboard.
- Long text wraps, truncates, or scrolls intentionally.

Common failure signs:

- Overflow stripes.
- Clipped primary button.
- Keyboard covers submit.
- Infinite width/height exception.
- White screen after navigation.

## Final Sign-Off

- Build:
- Supabase project:
- Tester:
- Date:
- Devices/viewports covered:
- Accounts used:
- Failed flows:
- Screenshots/videos attached:
- Go/no-go recommendation:

