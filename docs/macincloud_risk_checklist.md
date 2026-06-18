# MacInCloud Risk Checklist

Use this to avoid wasting paid macOS session time.

## Account Risks

- Apple Developer membership may not be active.
- App Store Connect role may not allow uploads.
- Apple ID two-factor authentication may require a trusted device.
- Agreements, Tax, and Banking may block app creation or upload.

## Build Environment Risks

- Xcode version may be too old for the current Flutter/iOS build.
- Flutter may not be installed on the rented Mac.
- CocoaPods may need update or repo refresh.
- MacInCloud account may not allow admin-level installs.
- Simulator build can pass while signing still fails.

## Signing Risks

- Bundle ID in Xcode must match App Store Connect.
- Signing team must own `com.matchaman.app`.
- Provisioning profile/certificate setup can fail.
- Changing Bundle ID late can break deep links and store identity.
- Apple certificates, profiles, `.p8` keys, and API keys must stay out of Git.

## Upload Risks

- IPA upload can fail after a successful local build.
- App Store Connect processing can take time.
- Missing metadata can block TestFlight review.
- External TestFlight requires Apple beta review.

## Security Cleanup

- Do not commit generated IPA files.
- Do not commit real Supabase values.
- Do not commit Apple credentials, reviewer passwords, certificates, profiles,
  or `.p8` files.
- Log out of Apple ID and App Store Connect before ending the session.
- Remove local clones or secret notes from the rented Mac if the provider
  requires manual cleanup.
