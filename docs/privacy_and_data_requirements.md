# Privacy And Data Requirements

This checklist is for engineering/product readiness. It does not claim legal compliance.

## Required Public Links

- Privacy Policy URL needed.
- Terms of Service URL needed.
- User Data Deletion URL or public instructions needed.
- Support email needed.

## Account And Deletion Flow

- Define how a user requests account deletion.
- Define how a user requests data deletion for social login providers.
- Decide support SLA and verification steps for deletion requests.
- Do not expose Supabase service role keys or internal admin credentials in client apps.

## Report And Block Behavior

- Users can report posts/users where report UI is available.
- Users can block other users.
- Blocked-user content should be hidden from feed/profile surfaces where the app already enforces this.
- Store review notes should explain report/block behavior for user-generated content.

## Public/Private Profiles

- Public profiles can be viewed by other authenticated users.
- Private profile extended content is limited to the owner and approved followers.
- Follow requests are used for private accounts.
- Public profile data should not expose email, phone, auth metadata, or provider tokens.

## Gallery And Archive Privacy

- Feed/gallery posts can be archived.
- Archived gallery content should be visible only to the owner.
- Public social images may be public only where that is the current product/storage decision.
- Missing avatars/images should fall back safely.

## Event Participation Data

- The app stores event participation state such as host/participant role and attendance/request status.
- Event history/profile surfaces should respect private profile visibility rules.
- Store copy should explain that event participation may be visible in social/event contexts.

## Social Login Data Usage

- Google and Facebook OAuth are handled through Supabase Auth.
- Social metadata may be used to bootstrap profile name/avatar only.
- Provider email should not be shown publicly.
- OAuth secrets must remain in provider dashboards/Supabase settings, not app code.

## Supabase Auth Data Usage

- Supabase Auth is the source of truth for signed-in users.
- Client apps use the Supabase anon key only.
- Service role keys must never be used in Flutter clients.

## Stored User Data Categories

- Auth identifiers and provider metadata managed by Supabase Auth.
- Profile fields: username, tag, name, city/district, bio, avatar URL, privacy status, trust score.
- Event fields: host, participants, attendance/request status, event location/date/sport metadata.
- Social content: posts, image URLs, captions, likes, comments.
- Safety content: reports, blocks, follow requests.
- Notifications stored in-app; push notifications are postponed.
