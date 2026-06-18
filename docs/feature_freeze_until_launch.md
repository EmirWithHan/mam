# Feature Freeze Until Launch

Do not add these before launch:

- Firebase push notifications.
- Apple Sign In unless required by review.
- Advanced business monetization.
- Complex ads.
- Major UI redesign.
- New chat architecture.
- Algorithmic feed.
- New admin panel expansion.
- AI features.
- Payment system.
- Large refactors.

Allowed before launch:

- BLOCKER fixes.
- HIGH core-flow fixes.
- Privacy/account deletion/store compliance.
- App icon/label/screenshots.
- Tiny copy/overflow fixes.
- Crash/white-screen fixes.
- Security/secrets cleanup.

Anything else should be deferred until after beta and public launch decisions.

During launch week, follow `docs/public_launch_hotfix_policy.md`. It narrows
allowed work to urgent stability, auth, compliance, metadata, and security
fixes.
