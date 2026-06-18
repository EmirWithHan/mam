# MacInCloud Session Checklist

Use this during the paid Mac session. Keep secrets out of repo files.

## 1. Start Session

- Log into MacInCloud.
- Confirm time/credit.
- Open Terminal.
- Do not paste secrets into repo files.
- Keep private values in temporary local notes only.

## 2. Check Tools

```bash
xcodebuild -version
git --version
pod --version
flutter --version
flutter doctor -v
```

## 3. Clone Project

```bash
git clone REPO_URL_PLACEHOLDER
cd PROJECT_FOLDER_PLACEHOLDER
flutter pub get
```

## 4. iOS Pods

```bash
cd ios
pod install
cd ..
```

## 5. Analyze/Test

```bash
flutter analyze
flutter test
```

## 6. Simulator/No-Signing Sanity Build

```bash
flutter build ios --simulator \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## 7. Open Xcode

```bash
open ios/Runner.xcworkspace
```

## 8. Xcode Checks

- Select Runner target.
- Set Team.
- Confirm Bundle Identifier.
- Confirm Signing & Capabilities.
- Confirm Deployment Target.
- Confirm Display Name.
- Confirm URL Schemes.
- Confirm App Icons.
- Confirm no unexpected Firebase/push capability.

## 9. Build IPA

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/ios/ipa/*.ipa
```

## 10. Upload

- Use Xcode Organizer or Transporter.
- Upload IPA to App Store Connect.
- Wait for processing.
- Do not commit IPA.

## 11. End Session Safely

- Log out of Apple ID if used.
- Delete local project if needed.
- Clear any local notes containing secrets.
- End MacInCloud session.
