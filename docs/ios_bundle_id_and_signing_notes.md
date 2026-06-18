# iOS Bundle ID And Signing Notes

## Current iOS Identity

- Bundle ID: `com.matchaman.app`.
- Display name: `Match A Man`.
- Minimum iOS version: `13.0`.
- URL scheme: `matchaman`.

`com.matchaman.app` is the final bundle identifier for the first TestFlight
upload. Changing the bundle ID after release creates store, signing, deep link,
and analytics migration work.

## Signing Rules

- App Store Connect app record must use the same Bundle ID as Xcode.
- Xcode signing must use the Apple Developer Team that owns the app record.
- Certificates, provisioning profiles, `.p8` keys, and Apple API keys must not
  be committed.
- Generated `.ipa` files must not be committed.
- Reviewer account passwords belong only in App Store Connect app access notes
  or a private password manager.

## Deep Link Alignment

Supabase redirect allowlist should include:

```text
matchaman://auth/callback
matchaman://reset-password
```

The iOS app must keep the `matchaman` URL scheme in `Info.plist` so email
confirmation and password reset links can return to the app.

## Manual Checks In Xcode

- `Runner` target Bundle Identifier is `com.matchaman.app`.
- Team is selected.
- Signing status is valid.
- Display name is `Match A Man`.
- App icon preview uses the Match A Man logo.
- URL scheme `matchaman` is present.
- No Firebase/push capability is added for this beta path.
