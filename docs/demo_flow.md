# Manual Demo Flow

This is a presenter script for the current Supabase-only MVP. Keep the pace calm and show that Match A Man is event-centered, social, sporty, and trustworthy.

## A. First Impression

1. Open the app from a clean state.
2. Show login and register entry points.
3. Register or log in as the new empty user.
4. Complete profile:
   - full name
   - username
   - city and district
   - short bio
   - avatar if available
5. Confirm the user lands safely in the main app.

## B. Event Discovery

1. Open the events list.
2. Scroll through upcoming events and point out sport, capacity, city/district, date, and host preview.
3. Use filters/search if available:
   - sport
   - city/district
   - date or keyword
4. Open an event detail page.
5. Tap host avatar/name in event detail and open the public profile.
6. Return with back navigation to the event detail page.

## C. Participation

1. As a regular user, request to join an event.
2. Show the pending state and disabled/deduplicated action behavior.
3. Cancel a pending request.
4. Switch to the host user.
5. Open the host event and review join requests.
6. Approve one request and reject another.
7. Switch to an approved participant.
8. Show approved state, participant visibility, and chat/call access gating.
9. Leave the approved event and confirm access changes.

## D. Social Layer

1. Open the feed.
2. Create a post, ideally linked to an event.
3. Like and comment on a post.
4. Open another user's public profile from a safe tappable surface.
5. Follow/unfollow the user and show follower/following counts.
6. Open followers/following lists if present.
7. Open gallery content and show polished empty or image states.

## E. Safety And Trust

1. Open a user or post action menu.
2. Submit a report using harmless demo content.
3. Block a demo user and confirm feed/event filtering behavior if visible.
4. Show trust score placement if available.
5. Explain participant visibility:
   - hosts see relevant request information
   - approved participants see intended participant surfaces
   - unrelated users do not see private participant details

## F. Notifications

1. Trigger or open prepared notifications.
2. Show event notification types:
   - join request
   - approved
   - rejected
   - cancelled
   - left
3. Tap an event notification and navigate to event detail.
4. Tap a follow/profile notification if prepared.
5. Mark one notification as read.
6. Use "Tümünü okundu yap" and confirm the unread indicator clears.

## G. Ending

Close with what is already working:

- Supabase Auth
- profile completion and profile pages
- event discovery and detail
- join request lifecycle
- chat/call access gating
- feed posts, likes, comments, follow, report, block
- public profiles, gallery, followers/following
- Supabase in-app notifications

Then state what is intentionally postponed:

- push notifications
- Firebase/FCM
- social login
- advanced moderation/admin tooling
- production analytics
- store submission assets and signing
