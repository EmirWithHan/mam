# iOS Release Checklist

## Current Status

- iOS bundle id: `com.matchaman.app`
- Display name: `MaM`
- Version/build comes from Flutter: `1.0.0+1`
- Deployment target: iOS 13.0
- URL scheme: `matchaman`
- Location permission string exists.
- App icon set includes a 1024x1024 icon.
- Apple login remains disabled/postponed.

## Blockers Before TestFlight/App Store

- Apple Developer Program account needed.
- Verify App Store Connect app record uses `com.matchaman.app`.
- Configure signing and provisioning.
- Prepare TestFlight tester plan.
- Publish Privacy Policy URL.
- Publish User Data Deletion URL/instructions.
- Prepare screenshots.
- Complete age rating.
- Revisit Sign in with Apple requirements if Google/Facebook remain available on iOS.

## Archive Command Placeholder

```bash
flutter build ipa --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
