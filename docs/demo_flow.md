# Match A Man Demo Flow

This script is for a Supabase-only MVP demo or closed beta walkthrough.

## A. First Impression

1. Open the app and show the auth entry point.
2. Show email login/register with friendly Turkish messages.
3. Show Google and Facebook login buttons using Supabase Auth.
4. Point out that Apple login is disabled and marked Yakında until Apple Developer Program is active.
5. Register or open a new user and show profile creation.
6. Confirm the public handle format: username#0000.
7. Explain that username and name/full_name are enough for general app access.

## B. Event Discovery

1. Browse the events list.
2. Use sport, city, or district filters if prepared.
3. Open event detail.
4. Open the host profile from event detail.
5. Open a past event and confirm it can be viewed but cannot be joined.
6. Confirm the past-event copy: "Bu etkinlik geçmişte kaldı."

## C. Event-Required Profile Flow

1. Log in as the new empty user.
2. Show that Home, Feed, Events browsing, Profile, and public profiles still load with username + name.
3. Try to join an event or create an event while city, district, or birth date is missing.
4. Show the prompt: "Etkinliklere katılmak için profilini tamamlamalısın."
5. Show the required info copy: "Gerekli bilgiler: şehir, ilçe ve doğum tarihi."
6. Tap "Profili tamamla" and confirm profile completion/edit opens, not Events directly.
7. Fill city, district, and birth date.
8. Save and return safely to the event detail/create flow when returnTo is available.
9. Retry join/create successfully after the profile is event-ready.

## D. Participation

1. Request to join an upcoming event.
2. Show pending state.
3. Cancel a pending request.
4. Re-request if the prepared event allows it.
5. Switch to the host user.
6. Approve one request and reject another.
7. Switch to an approved participant and leave an event.
8. Open a full event and confirm full-capacity behavior appears before profile prompts.
9. Confirm participant visibility follows the intended host/participant/privacy rules.

## E. Social Layer

1. Open Feed.
2. Create or show an event-linked post.
3. Like and comment on a post.
4. Follow a public account.
5. Open followers and following lists.
6. Open a public profile.
7. Open Gallery and the gallery viewer.
8. Confirm author rows and profile headers use username#0000.

## F. Privacy

1. Open a public profile and show allowed content.
2. Open a private profile as a non-follower.
3. Confirm Gallery and Geçmiş Events are locked.
4. Confirm locked copy: "Bu alanı görmek için kullanıcıyı takip etmelisin."
5. Send a follow request.
6. Switch to the private profile owner and open notifications.
7. Approve one follow request and reject another if prepared.
8. Return as the approved follower and confirm Gallery and Geçmiş Events are visible.
9. Show an archived gallery item as the owner.
10. Confirm archived gallery items are hidden from other users.

## G. Safety And Trust

1. Show trust score where it appears.
2. Show report controls on a harmless demo post.
3. Demonstrate block behavior with the safety demo user.
4. Confirm participant visibility does not expose private event information to unrelated users.
5. Show chat/call access gating if the prepared event has it enabled.

## H. Notifications

1. Open the notifications page.
2. Show an event join request notification.
3. Tap an event notification and open event detail.
4. Show a follow notification.
5. Show a follow request notification with Onayla/Reddet actions.
6. Approve or reject from the notification tile.
7. Mark one notification as read.
8. Mark all notifications as read and confirm unread indicators clear.
9. Confirm empty state copy appears when relevant: "Henüz bildirimin yok."

## I. Ending

1. Summarize what is already working: Supabase Auth, email auth, Google/Facebook OAuth, profile onboarding, username#0000 handles, public/private profiles, follow requests, gallery controls, events, participation, feed, and Supabase in-app notifications.
2. Summarize what is intentionally postponed: Firebase/FCM push, realtime notifications, active Apple login, production analytics, advanced moderation, payments, admin panel, and store release assets.
3. Ask beta users to focus on auth recovery, profile completion, event join/create, privacy boundaries, notifications, and obvious UI overflow.
