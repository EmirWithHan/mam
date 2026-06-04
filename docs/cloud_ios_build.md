# Cloud iOS Build

Date: 2026-06-04

## Why Cloud macOS Is Used

The current development machine is Windows and cannot run an iOS build locally.
Until a Mac is available, GitHub Actions can run a macOS runner to validate that
the Flutter iOS target compiles without code signing.

## Workflow

Workflow file:

```text
.github/workflows/ios_no_codesign_build.yml
```

Workflow name:

```text
iOS No-Codesign Build
```

The workflow can be started manually with `workflow_dispatch`. It also runs on
pushes to `main` when Flutter/iOS/test/workflow files change.

## How To Run Manually

1. Push this workflow file to GitHub.
2. Open the repository on GitHub.
3. Go to `Actions`.
4. Select `iOS No-Codesign Build`.
5. Choose `Run workflow`.
6. Select the branch to test.
7. Start the run and watch the logs.

## What The Workflow Runs

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
cd ios && pod install && cd ..
flutter build ios --debug --no-codesign
```

## What No-Codesign Build Validates

- Flutter dependencies resolve on macOS.
- CocoaPods can install iOS pods.
- The iOS Xcode project can compile in debug mode.
- iOS plugin integration is basically valid.
- `Info.plist` is present and readable by the iOS build.

## What It Does Not Validate

- App Store or TestFlight signing.
- Certificates, provisioning profiles, or Apple Developer team setup.
- Real iPhone install.
- Simulator runtime behavior.
- Push notifications.
- Apple login setup.
- Store privacy labels, screenshots, or review metadata.

## Current iOS Checks

- Display name is `Match A Man`.
- Bundle ID is `com.matchaman.app`.
- Photo library permission text exists for gallery image selection.
- Location permission text exists for event location autofill.
- Camera permission is not declared because camera capture is not implemented.
- Apple login remains postponed/coming soon and no Apple Developer config is
  added.

## If The Action Fails

Use the first failed step as the main diagnosis:

- `flutter pub get`: dependency or SDK resolution problem.
- `flutter analyze`: Dart analyzer issue.
- `flutter test`: failing unit/widget test.
- `pod install`: CocoaPods/plugin/iOS pod issue.
- `flutter build ios --debug --no-codesign`: Xcode project, plugin compile, or
  iOS build setting issue.

The failure diagnosis step prints a short reminder that the workflow uses no
secrets, no signing, no Firebase/push setup, and no TestFlight deployment.

## Remaining iOS TODOs

- Run simulator and real-device QA on a Mac later.
- Configure Apple Developer team and signing when ready.
- Prepare TestFlight only after signing is available.
- Revisit Sign in with Apple requirements before public iOS release if
  Google/Facebook login remain available.
- Prepare App Store privacy details, support URL, data deletion URL, screenshots,
  and reviewer notes.
