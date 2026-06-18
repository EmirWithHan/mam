# iOS App Store and TestFlight Readiness

## Purpose

This document tracks what is needed to publish Match A Man to TestFlight and
the App Store. The current repository can be compiled for iOS without signing,
but TestFlight/App Store distribution still requires Apple account setup and a
signed IPA.

## Current iOS Project Audit

- Bundle identifier: `com.matchaman.app`
- Display name: `Match A Man`
- Minimum iOS version: `13.0`
- Workspace: `ios/Runner.xcworkspace`
- Xcode project: `ios/Runner.xcodeproj`
- Podfile: not present in this checkout. The no-codesign workflow skips manual
  `pod install` when `ios/Podfile` is absent.
- Entitlements file: not present.
- App icon source asset: `assets/branding/mam_logo.jpg`
- iOS app icon catalog: `ios/Runner/Assets.xcassets/AppIcon.appiconset`

## Required Apple Items

- Apple Developer Program membership.
- App Store Connect access.
- App Store Connect app record.
- Registered Bundle ID for `com.matchaman.app`.
- Apple Team ID.
- Signing certificate.
- Provisioning profile.
- App Store Connect API key only if CI upload is added later.

Never commit Apple certificates, provisioning profiles, `.p8` files, API keys,
passwords, or signing secrets.

## Local Mac/Xcode Path

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the Runner target.
3. Set the Apple Team.
4. Confirm the Bundle Identifier is `com.matchaman.app`.
5. Configure Signing & Capabilities.
6. Archive the app.
7. Validate the archive.
8. Upload to App Store Connect.
9. Release first to TestFlight.

## Flutter IPA Command Template

Run this only on macOS with Xcode and signing configured:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/ios/ipa/*.ipa
```

Do not print or commit real Supabase values. Do not commit generated IPA files.

## CI Path Later

The existing GitHub Actions workflow
`.github/workflows/ios_no_codesign_build.yml` compiles iOS without secrets. It
runs dependency install, `flutter analyze`, `flutter test`, and
`flutter build ios --debug --no-codesign`.

Signed IPA upload from CI is a separate future step. It requires Apple signing
secrets and App Store Connect credentials stored securely in CI secrets, never
in the repository.

## Current Limitation

A passing no-codesign build only proves the code can compile for iOS. It does
not mean TestFlight or App Store upload is ready. Real TestFlight distribution
requires a signed IPA, App Store Connect setup, and Apple review for external
testers.

## Email Auth and Reset Links

The shared deep link scheme is configured in `ios/Runner/Info.plist`:

```text
matchaman
```

Supabase redirect URLs should include:

```text
matchaman://auth/callback
matchaman://reset-password
```

Expected iOS flows:

- Email signup shows `E-postani dogrula` pending UI.
- The user opens the confirmation email and taps the link.
- iOS opens Match A Man through `matchaman://auth/callback`.
- Supabase refreshes the auth session.
- The user continues to username onboarding when needed.
- Password reset links open the app through `matchaman://reset-password`.

Do not log full auth URLs, access tokens, refresh tokens, confirmation tokens,
or reset links.

## Manual TODO

- Create Apple Developer account access if not already available.
- Register/confirm Bundle ID ownership.
- Create App Store Connect app record.
- Configure signing in Xcode.
- Build and upload a signed IPA from macOS.
- Confirm iOS deep links using real Supabase redirect URLs.
- Prepare App Store screenshots and review metadata.
