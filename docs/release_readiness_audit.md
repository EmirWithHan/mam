# Release Readiness Audit

Last reviewed: 2026-05-28

This is an engineering/product readiness audit for closed beta and future store submission. It is not a legal compliance statement.

## Current App Identity

- App name in app UI/docs: Match A Man / MaM
- Flutter package name: `match_a_man`
- pubspec version/build: `1.0.0+1`
- Android namespace: `com.example.mam`
- Android applicationId: `com.example.mam`
- Android app label: `MaM`
- iOS bundle id: `com.example.mam`
- iOS display name: `MaM`
- Web title: `MaM`
- Web manifest name/short_name: `MaM`

## Beta Finalization

- Confirm beta display name: `MaM` vs `Match A Man`.
- Confirm version/build number strategy before distributing test builds.
- Replace placeholder Android package/applicationId before Play Console testing.
- Replace placeholder iOS bundle id before TestFlight.
- Confirm release Supabase redirect URLs for the selected package/bundle/domain setup.
- Keep secrets supplied through `--dart-define`, CI secrets, or local environment only.

## Store Submission Finalization

- Finalize legal app name, subtitle, category, descriptions, screenshots, and review notes.
- Publish Privacy Policy, Terms of Service, and User Data Deletion pages.
- Configure Android signing and iOS signing/provisioning.
- Complete Play Console Data Safety and App Store privacy labels.
- Revisit Sign in with Apple requirements before public iOS launch if Google/Facebook remain available.

## App Icon And Splash

- Source icon asset exists: `assets/branding/mam_logo.jpg`.
- Source icon dimensions inspected: 1024x1024.
- iOS 1024 app icon exists: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`.
- Android launcher icons exist in `android/app/src/main/res/mipmap-*`.
- Web icons exist in `web/icons/`.
- `flutter_launcher_icons` is configured in `pubspec.yaml`.
- `flutter_native_splash` is configured in `pubspec.yaml`.
- Android launch background XML still has the default white background file, so verify generated splash output before release.
- iOS launch storyboard references `LaunchImage`; verify it shows the intended brand splash on device.

## Current Blockers

- Android and iOS identifiers are still `com.example.mam`.
- Android release signing uses the debug signing config.
- Privacy Policy URL is not finalized.
- Terms of Service URL is not finalized.
- User Data Deletion URL/instructions are not finalized.
- Meta/Facebook app submission setup is not complete.
- Apple Developer Program/signing is not ready.
- Apple login is postponed.
