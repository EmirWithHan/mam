# MacInCloud iOS Build Day Runbook

This runbook is for building and uploading a signed iOS TestFlight build from
macOS. Do not run `flutter build ipa` on Windows.

Related launch planning:

- Master timeline: `docs/master_launch_timeline.md`.
- Critical blockers: `docs/critical_path_checklist.md`.
- Manual timing decisions: `docs/manual_decision_guide.md`.
- Next actions: `docs/next_actions_checklist.md`.
- Upload day gate: `docs/ios_testflight_upload_day_gate.md`.
- Session checklist: `docs/macincloud_session_checklist.md`.
- Xcode signing checklist: `docs/xcode_signing_checklist.md`.
- IPA troubleshooting: `docs/ios_ipa_upload_troubleshooting.md`.
- First TestFlight build checklist:
  `docs/testflight_first_build_checklist.md`.
- App Store review notes draft: `docs/app_store_review_notes_draft.md`.

## Phase 0 - Before Paid Mac Time

- Confirm Apple Developer Program and App Store Connect access.
- Confirm Bundle ID `com.matchaman.app` is the final iOS identifier.
- Confirm Supabase redirect URLs include:
  - `matchaman://auth/callback`
  - `matchaman://reset-password`
- Confirm Apple ID two-factor device is available.
- Confirm real Supabase URL and anon key are available only in a private local
  note or password manager.
- Confirm no Apple certificates, profiles, `.p8` keys, IPA files, or real
  secrets are in Git.
- Push the latest repository changes.

## Phase 1 - Connect To Mac

```bash
xcodebuild -version
git --version
pod --version
```

If any required tool is missing, install it using the MacInCloud-approved path.
Do not put credentials in shell history when avoidable.

## Phase 2 - Flutter Setup

```bash
flutter --version
flutter doctor -v
```

If Flutter is missing, install it in the user account according to the current
Flutter macOS installation guide. Avoid system-wide changes unless the Mac
provider explicitly allows them.

## Phase 3 - Clone And Dependencies

```bash
git clone YOUR_PRIVATE_REPO_URL
cd mam
flutter pub get
cd ios
pod install
cd ..
```

Do not copy local `.env` files, signing keys, or reviewer credentials into the
repo.

## Phase 4 - No-Signing Compile Check

```bash
flutter build ios --simulator \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

This confirms the iOS project compiles before signing work starts.

## Phase 5 - Xcode Signing

- Open `ios/Runner.xcworkspace`.
- Select the `Runner` target.
- Confirm display name is `Match A Man`.
- Confirm Bundle Identifier is `com.matchaman.app`.
- Select the Apple Developer Team.
- Let Xcode manage signing if that is the chosen beta path.
- Confirm deployment target is compatible with iOS `13.0`.
- Confirm URL scheme `matchaman` exists.
- Confirm the app icon is the Match A Man icon, not the Flutter icon.

## Phase 6 - Build Signed IPA

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Expected output:

```text
build/ios/ipa/*.ipa
```

Do not commit IPA output.

## Phase 7 - Upload

- Upload with Xcode Organizer or Transporter.
- Wait for App Store Connect processing.
- Fix signing or metadata errors on the Mac; do not change package identity.
- Delete local secret notes before ending the rented session.
- Log out of Apple services before ending the session.

## Phase 8 - TestFlight

- Add the processed build to an internal testing group first.
- Install from the TestFlight app.
- Run the internal smoke checklist.
- Use `docs/testflight_first_build_checklist.md` before inviting external
  testers.
- Submit external TestFlight beta review only after internal install succeeds.

## Build Command Template

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```
