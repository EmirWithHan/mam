# Known Limitations

This document lists intentional MVP limitations for demo and closed beta planning. These are not surprises or secret blockers; they are items to communicate clearly before wider release.

## Postponed Platform Features

- Push notifications are postponed.
- Firebase/FCM is not active.
- Firebase Auth was not added.
- Realtime notifications are not implemented.
- Apple login is postponed until Apple Developer Program is active.
- Apple Developer Program is required for iOS device distribution, TestFlight, and App Store submission.

## Product And Operations

- Advanced moderation tooling is postponed.
- Production-grade abuse detection is not implemented.
- Advanced rate limiting may need backend review before a larger public launch.
- Production analytics are postponed.
- Admin panel is not implemented.
- Real payment/monetization is not implemented.

## Store And Release Readiness

- App Store and Play Store assets are pending.
- Facebook/Meta public launch remains blocked until app icon, Privacy Policy URL, User Data Deletion URL/instructions, category, and app mode are completed.
- Facebook Development Mode is limited to roles/test users.
- Store screenshots, descriptions, privacy copy, and review notes need final review.
- Data deletion request handling should be documented before store submission.
- Content moderation and report/block behavior should be described clearly for reviewers.
- Android release signing is not configured.
- iOS Apple Developer signing/provisioning is not configured.

## Beta Expectations

- Closed beta should focus on auth, onboarding, event discovery, event participation, privacy boundaries, follow requests, gallery controls, notifications, and UI stability.
- Beta users should not expect push alerts, realtime inbox updates, production analytics, payments, or admin tooling.
