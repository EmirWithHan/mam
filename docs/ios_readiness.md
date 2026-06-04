# iOS Readiness

Date: 2026-06-04

## iOS Status

Status: Audit-ready on Windows, Mac/Xcode build still required.

The Flutter app has iOS project files in place and the user-visible iOS app
name is `Match A Man`. This pass audited the iOS metadata, permission strings,
Apple login status, and keyboard-sensitive Flutter screens from Windows. A real
iOS build was not attempted because this machine is Windows.

## Project Files Checked

- `ios/Runner/Info.plist`
- `ios/Runner.xcodeproj/project.pbxproj`
- `ios/Runner.xcworkspace`
- `ios/Runner/Assets.xcassets`

## App Identity

- Display name: `Match A Man`
- Bundle identifier: `com.matchaman.app`
- URL scheme: `matchaman`
- App icon assets exist in `AppIcon.appiconset`.
- Launch image assets exist in `LaunchImage.imageset`.
- Xcode target name still uses Flutter's standard `Runner` target internally;
  this is not user-visible because `CFBundleDisplayName` and `CFBundleName` are
  set to `Match A Man`.

## Apple Developer And TestFlight TODO

- Apple Developer account is required.
- A Mac with Xcode is required for iOS build/signing validation.
- Confirm final ownership of bundle ID `com.matchaman.app`.
- Configure signing team, provisioning profiles, and capabilities in Xcode.
- Run `flutter build ios --debug --no-codesign` on Mac first.
- Prepare TestFlight tester notes and reviewer test accounts.
- Revisit Sign in with Apple requirements if Google/Facebook login remain
  available on iOS.

## Apple Login

- Apple login is postponed.
- The app currently shows Apple as coming soon/Yakinda.
- Do not fake Apple login.
- Do not add Apple Developer config until the Apple Developer setup is ready.

## Permissions Checklist

| Permission | Status | Notes |
| --- | --- | --- |
| Photo library | Present | Used for profile avatar and feed image selection from gallery. |
| Camera | Not present | No camera capture flow was found; do not add until camera is actually used. |
| Location when in use | Present | Used when the user taps the event location action. |

Permission copy is MVP-safe and does not imply background tracking or automatic
permission prompts at first launch.

## Keyboard And Safe Area Audit

Audited screens:

- Auth/login/register
- Profile completion
- Create post
- Create event
- Business application
- Feedback form
- Chat input
- Settings

Findings:

- The audited pages use `SafeArea`.
- Form-heavy pages use `ListView` so fields and primary buttons can scroll
  above the keyboard.
- Chat uses an expanded message list with the composer at the bottom and stacks
  the send button on very narrow widths.
- No obvious iPhone-size overflow fix was required during static inspection.

## iOS Layout Sizes To Manually Verify

- 390x844
- 393x852
- 430x932

Manual QA should confirm:

- No RenderFlex overflow.
- No infinite width error.
- No clipped primary button.
- Keyboard does not hide the active text input or submit button.
- No white screen after auth/session restore or deep-link return.

## Known iOS Risks

- Real iOS build and signing have not been validated on Mac/Xcode.
- Apple Developer Program setup is still pending.
- TestFlight is not configured.
- Apple login remains postponed.
- iOS App Store privacy labels, data deletion URL, support URL, screenshots,
  and reviewer notes still need final preparation.
- Social login callback behavior should be tested on a real iOS device after
  Supabase redirect URLs are finalized.
