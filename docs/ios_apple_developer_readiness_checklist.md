# iOS Apple Developer Readiness Checklist

Use this before starting paid MacInCloud time or attempting a TestFlight upload.

## Apple Account

- Apple Developer Program membership is active.
- App Store Connect login works with the account that will upload the build.
- Two-factor authentication device is available during the build session.
- Agreements, Tax, and Banking has no blocking agreement.
- App Store Connect team role can create apps, manage signing, and upload builds.
- Apple credentials are not stored in this repo, scripts, notes, screenshots, or docs.

## App Identity

- App name: `Match A Man`.
- Bundle ID: `com.matchaman.app`.
- iOS display name: `Match A Man`.
- Minimum iOS version: `13.0`.
- URL scheme: `matchaman`.
- Required Supabase redirect URLs:
  - `matchaman://auth/callback`
  - `matchaman://reset-password`

## Store Inputs

- Privacy policy URL is ready or has a final hosting plan.
- Account deletion URL or support process is ready.
- Support email is ready.
- Reviewer test account instructions can be entered in App Store Connect only.
- Real reviewer passwords are not committed.
- App icon source is ready: `assets/branding/mam_logo.jpg`.
- iOS screenshots are still manual capture items.

## Before MacInCloud

- Latest code is pushed to the private remote that will be cloned on the Mac.
- `flutter analyze` and `flutter test` pass locally.
- Supabase email confirmation and password reset links work on Android.
- Supabase redirect allowlist includes the iOS custom scheme links.
- No `.env`, Supabase keys, Apple certificates, provisioning profiles, `.p8`
  keys, IPA files, or reviewer credentials are committed.

## Done When

- Apple Developer access is confirmed.
- App Store Connect can create the app record for `com.matchaman.app`.
- Signing can be configured on the Mac without changing package identity.
- The MacInCloud runbook can be followed without waiting for missing account
  setup.
