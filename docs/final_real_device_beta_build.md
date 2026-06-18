# Final Real Device Beta Build

## Purpose

This document explains how to create the APK for real-device Android beta
testers. This is not the Play Store signed AAB process. This APK is for
controlled manual testing before closed testing/store upload.

## Required Build Command

Use placeholder values in docs. Use real local/CI values only when building on
your machine.

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## Output Path

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Copy To Desktop

```powershell
copy build\app\outputs\flutter-apk\app-debug.apk "$env:USERPROFILE\Desktop\Match_A_Man_debug.apk"
```

## Tester Install Notes

- Send the APK as a WhatsApp/Drive document, not as an image.
- Tester may need to allow unknown source installs.
- Tester should uninstall the old APK before installing the new APK.
- Android may cache the old app icon if installing over an older build.
- Tester should use a real email address.
- Tester should check spam/junk for the verification email.

## Tester First-Run Checklist

- [ ] Install APK.
- [ ] Register with a real email.
- [ ] See `E-postanı doğrula`.
- [ ] Tap the email verification link.
- [ ] App opens.
- [ ] Choose username.
- [ ] Enter app.
- [ ] Test Home/Akış.
- [ ] Test Etkinlikler.
- [ ] Test Profil.
- [ ] Test Kullanıcı ara.
- [ ] Test Ayarlar.
- [ ] Try forgot password if possible.

## Known Beta Limitations

- This is a beta build; bugs may happen.
- Firebase/push notifications are not active.
- iOS real-device testing is later.
- Play Store closed testing is a separate signed AAB process.
- Some legal/privacy/store items are still in preparation.

## Optional Smaller Manual APK

For smaller direct install testing, a split release APK can be built later:

```powershell
flutter build apk --release --split-per-abi `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Modern Android phones usually use:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
