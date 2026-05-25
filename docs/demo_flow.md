# Match A Man Demo Flow

This script is for a Supabase-only MVP demo or closed beta walkthrough.

## A. First Impression

1. Open the app and show the clean auth entry point.
2. Log in with the host user.
3. Optionally register or open the new empty user to show profile completion.
4. Complete or review required profile fields: name, username, city, district, bio, and avatar.
5. Point out that Supabase Auth is the source of truth.

## B. Event Discovery

1. Open the events/home area.
2. Browse active events and show clean loading/empty states if applicable.
3. Apply a city or sport filter.
4. Open an event detail page.
5. Tap the host avatar/name from event detail and open the public profile.
6. Navigate back to event detail.

## C. Participation

1. As a normal user, request to join an upcoming event.
2. Show the pending state and cancel the pending request.
3. Request again, then switch to the host account.
4. Approve one request and reject another request.
5. As an approved participant, leave an event.
6. Open a past event and show that it can be viewed but cannot be joined.
7. Confirm the disabled message: "Bu etkinlik geçmişte kaldı."

## D. Social Layer

1. Open the feed.
2. Create or show an event-linked post.
3. Like and comment on a post.
4. Follow a public account and show the button changing to "Takip Ediliyor".
5. Open followers and following lists from a profile stat card.
6. Tap a list row and navigate to that user's public profile.
7. Open the gallery and gallery viewer.

## E. Privacy

1. Open a public profile and show that basic profile, gallery, and Geçmiş Events are visible.
2. Open a private profile as a non-follower.
3. Show that the profile header and counts are visible, but gallery and Geçmiş Events are locked.
4. Confirm the locked copy: "Bu alanı görmek için kullanıcıyı takip etmelisin."
5. Tap "Takip Et" on the private profile and show the button changing to "İstek Gönderildi".
6. Switch to the private profile user and open notifications.
7. Approve one follow request from the notification tile.
8. Reject another follow request from the notification tile if prepared.
9. Return as the approved requester and show that gallery and Geçmiş Events are now visible.
10. As the owner, show an archived gallery item with the lock overlay.
11. As another user, confirm the archived gallery item is not visible.

## F. Safety And Trust

1. Show trust score where it appears in profile or user rows.
2. Demonstrate participant visibility: approved/allowed viewers can see intended participant data, unrelated users cannot.
3. Show chat/call access gating from an event where access is allowed only for the correct state.
4. Open report controls on a safe demo post.
5. Demonstrate block behavior using a harmless demo account.

## G. Notifications

1. Trigger or show an event join request notification.
2. Open the notifications page.
3. Tap an event notification and navigate to the related event detail.
4. Show a public follow notification: "Yeni takipçi".
5. Show a private follow request notification with "Onayla" and "Reddet".
6. Approve/reject from the notification tile and confirm buttons disappear or become inactive.
7. Mark one notification as read.
8. Use "Tümünü okundu yap" and confirm unread indicators clear.

## H. Ending

1. Summarize what is already working: auth, profiles, public/private privacy, follow requests, gallery controls, events, participation, feed, follow lists, and in-app notifications.
2. Clarify what is intentionally postponed: Firebase/FCM push, realtime notifications, social login, advanced moderation, analytics, admin tooling, and store release assets.
3. End with the closed beta checklist and known limitations documents.
