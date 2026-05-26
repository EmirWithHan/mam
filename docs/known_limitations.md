# Known Limitations

This document lists intentional MVP limitations for demo and closed beta planning.

## Postponed Platform Work

- Push notifications are postponed.
- Firebase/FCM is not active.
- Realtime notifications are not implemented.
- Apple login is postponed until Apple Developer Program setup is available.
- App Store and Play Store assets are pending.
- Store signing, provisioning, and release metadata are not complete.

## Product And Operations

- Advanced moderation is postponed.
- Production-grade abuse detection is not implemented.
- Admin panel is not implemented.
- Production analytics are postponed.
- Real payment or monetization flows are not implemented.
- Advanced rate limiting may need backend review before a wider launch.

## Beta Expectations

- In-app notifications are Supabase-backed and require users to open the app.
- Follow request approval/rejection is in-app only; there is no push alert yet.
- Username and name are enough for general app access. City, district, and birth
  date are required only for event participation/creation, and event-launched
  profile completion returns through a safe internal path.
- Closed beta should use staged accounts and staged demo data.
- Demo data should not include real personal data.
- Privacy behavior should be validated after every Supabase migration push.
- Any public launch should wait for privacy policy, terms, support process, and data deletion process approval.
