# Match A Man Demo Environment Setup

## Purpose

This guide helps prepare a safe, repeatable demo environment for Match A Man. Use it before presenting the MVP so auth, events, join requests, chat, feed, profile, and safety flows are ready without exposing private data.

## Required Local Setup

- Flutter installed.
- Emulator or physical device ready.
- Supabase project available.
- Correct Supabase Project URL.
- Correct Supabase anon/public key.
- Never use the Supabase `service_role` key in Flutter.

## Running the App Locally

PowerShell example:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

Do not commit real keys. A VS Code launch config can be used for convenience, but it should not be committed with real Supabase values.

## Supabase Auth Settings for Demo

- Email/password provider enabled.
- Email confirmation can be disabled for local demo speed.
- For production, email confirmation should be reviewed again.
- Use test accounts only.

## Demo Test Accounts

Suggested placeholders:

- `host@example.com`
- `participant@example.com`
- `outsider@example.com`

Do not use real personal accounts. Do not reuse production passwords. Use simple test data only in development.

## Demo Data to Prepare

User A / Host:

- Completed profile.
- Avatar.
- Phone number for call button testing if safe.
- One event created.

User B / Participant:

- Completed profile.
- Avatar.
- One join request to User A's event.
- Approved participant state.

Feed:

- At least one photo post from User A.
- At least one photo post from User B.
- One like.
- One comment.

Social:

- At least one approved event chat.
- At least two messages in the event chat.

Reports/Blocks:

- Optional demo only.
- Do not over-demonstrate safety actions unless asked.

## Manual Demo Reset Tips

- Use fresh test users if state becomes messy.
- If an event join request unique constraint blocks repeated tests, use a new event or a new participant user.
- If feed images become messy, create fresh posts.
- If the call button uses real phone numbers, avoid showing the number publicly.

## Privacy and Safety Checklist Before Demo

- [ ] `service_role` key is not in Flutter code.
- [ ] Phone is not visible publicly.
- [ ] `birth_date` is not visible publicly.
- [ ] Public profile previews show safe fields only.
- [ ] Report/block actions are not visible on own content.
- [ ] Storage images are expected to be public only if intended.
- [ ] Call button only appears for allowed host/approved participant flows.

## Known Demo Limitations

- No direct messages yet.
- No realtime chat yet.
- No push notifications yet.
- No maps yet.
- No business panel yet.
- No admin moderation panel yet.
- No advanced trust score automation yet.

## Final Pre-Demo Checklist

- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] App runs on emulator/device.
- [ ] Login works.
- [ ] Events load.
- [ ] Join request flow works.
- [ ] Chat works.
- [ ] Feed works.
- [ ] Profile/settings work.
- [ ] No obvious UI overflow.
- [ ] Demo accounts are ready.
