# iOS IPA Upload Troubleshooting

## 1. CocoaPods Fails

Fix:

- Run `pod repo update` if needed.
- Run `pod install` again.
- Check the Podfile platform.

## 2. Xcode Signing Fails

Fix:

- Verify Apple Developer membership.
- Verify Team.
- Verify Bundle ID.
- Verify provisioning profile.
- Verify App Store Connect app record.

## 3. Bundle ID Already Used

Fix:

- Choose the final correct bundle ID.
- Update Xcode and App Store Connect consistently.
- Do not change only one side.

## 4. App Icon Missing

Fix:

- Regenerate icons using the existing Match A Man logo.
- Verify `Assets.xcassets/AppIcon`.

## 5. Deep Link Does Not Open App

Fix:

- Check `Info.plist` URL scheme.
- Check Supabase redirect URLs.
- Check `redirectTo` values in code.

## 6. Transporter Upload Fails

Fix:

- Check Apple ID/App Store Connect access.
- Check bundle ID.
- Check version/build number.
- Check the App Store Connect app record exists.

## 7. Build Number Already Used

Fix:

- Bump iOS build number/version in `pubspec.yaml`.
- Rebuild IPA.

## 8. Privacy/Metadata Warning

Fix:

- Finish privacy policy, App Privacy, and app access info in App Store Connect.
- Do not enter reviewer credentials in the repo.
