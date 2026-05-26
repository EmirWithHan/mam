# Security Follow-Ups

This pass audited the current Supabase-only MVP for closed beta readiness. It focused on RLS/RPC consistency, privacy boundaries, event participation, notifications, report/block behavior, storage assumptions, trust score safety, and user-facing error safety.

## Audited

- Profiles and public profile RPCs.
- Public/private profile visibility.
- Gallery archive/comment controls.
- Follow and follow request RPC ownership checks.
- Followers/following list RPCs.
- Event list/detail/create/join/approve/reject/cancel/leave client calls and available RPCs.
- Event public participant preview data.
- Supabase in-app notifications read/update actions.
- Reports, blocks, and trust score client access.
- Storage usage for avatar/feed/gallery-style media.
- RPC execute grants in the available migrations.
- User-facing error mapping for common Supabase/RLS failures.

## Fixed In This Pass

- Feed loading now uses `get_visible_feed_posts()` so archived posts, private-account posts from non-followed users, and blocked-user posts are filtered server-side before the client receives rows.
- `get_event_public_participants()` now returns only the host and active approved participants (`planned` or `attended`), preventing pending/rejected/left participant rows from appearing in the public participant preview RPC.
- Client-side event participant mapping now keeps the same visibility rule as a defensive fallback.
- Added a regression test for public participant visibility states.

## Closed Beta Risks

- Some base RLS policies and older RPCs are not fully represented in the visible migration history. They should be reviewed directly in the Supabase dashboard before expanding the beta.
- Event create/join capacity and trust score penalties depend on existing RPC implementations that are referenced by the app but not defined in the visible migrations. Confirm server-side enforcement before production.
- Comments hidden behavior is checked by the client before reading/adding comments. Confirm RLS or RPC-side enforcement for `post_comments` before production.
- Reports and blocks use direct table access from the client. Confirm RLS prevents reading, modifying, or deleting another user's records.
- Trust score logs are read directly for the current user. Confirm normal users cannot insert or update `trust_score_logs` or directly edit `profiles.trust_score`.
- Storage buckets for avatars/feed/gallery media may be public, which is acceptable for intentionally public social media but not for private documents. Archived/private visibility must continue to be enforced by database queries, not storage URL secrecy.

## Must Revisit Before Production

- Run a full Supabase policy review for `profiles`, `events`, `event_participants`, `event_join_requests`, `posts`, `post_comments`, `post_likes`, `follows`, `follow_requests`, `notifications`, `reports`, `blocks`, `trust_score_logs`, and storage buckets.
- Revoke `PUBLIC` execute on all custom RPCs and grant only the required roles.
- Confirm every `security definer` RPC sets a safe `search_path` and uses `auth.uid()` for ownership checks.
- Move comment visibility, feed visibility, and event participant visibility entirely behind audited RPCs/RLS.
- Add abuse controls for follow request spam, report spam, event request spam, and repeated block/unblock patterns.
- Add production-grade rate limiting and abuse detection.
- Add an admin/moderation panel before wider public release.

## Postponed Platform Items

- Push notifications remain postponed.
- Firebase/FCM is not active.
- Firebase Auth was not added.
- Realtime notifications are postponed.
- Apple login remains postponed until Apple Developer Program is active.
