# Email Auth Real Device QA

Use this checklist for Android closed beta verification of Supabase email
confirmation links and password reset links.

## Debug APK Build

Build with dart-defines. Do not commit real values.

```powershell
flutter build apk --debug ^
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" ^
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

APK path:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## 1. Fresh Email Signup

- [ ] Uninstall the existing app from the phone.
- [ ] Install the debug APK.
- [ ] Register with an unused real email.
- [ ] App shows `E-postanı doğrula`.
- [ ] App shows `E-posta adresine doğrulama bağlantısı gönderdik.`
- [ ] App shows the email address.
- [ ] User cannot enter the main shell before clicking the email verification
  link.

## 2. Confirmation Link

- [ ] Open the confirmation email on the phone.
- [ ] Tap the verification link.
- [ ] App opens through the `matchaman://auth/callback` deep link.
- [ ] If this is the first login and no username exists, app shows
  `Kullanıcı adını seç`.
- [ ] User chooses a username and continues to the main shell.
- [ ] Full profile completion is not required during first onboarding.
- [ ] Supabase Auth user becomes confirmed.

## 3. Unverified Login

- [ ] Create a fresh account.
- [ ] Do not click the confirmation link.
- [ ] Try to log in.
- [ ] App shows `E-posta adresini doğrulaman gerekiyor.`
- [ ] Raw Supabase errors are not shown.

## 4. Resend Confirmation

- [ ] On the pending screen, tap `E-postayı tekrar gönder`.
- [ ] App shows `Doğrulama bağlantısı tekrar gönderildi.`
- [ ] A new confirmation email arrives.
- [ ] Document whether the old link still works or Supabase marks it expired.

## 5. Password Reset

- [ ] Log out.
- [ ] Tap `Şifremi unuttum`.
- [ ] Enter the email.
- [ ] Tap `Bağlantı gönder`.
- [ ] App shows `Şifre sıfırlama bağlantısı e-postana gönderildi.`
- [ ] Open the reset email on the phone.
- [ ] App opens the `Yeni şifre belirle` screen through
  `matchaman://reset-password`.
- [ ] Enter `Yeni şifre` and `Yeni şifre tekrar`.
- [ ] Tap `Şifreyi güncelle`.
- [ ] Log in with the new password.

## 6. Broken Link Cases

- [ ] Open an old or expired link if possible.
- [ ] App shows a friendly Turkish error.
- [ ] App does not crash, loop, show a white screen, or stay loading forever.
- [ ] No access token, refresh token, code, or full auth URL appears in logs.

## 7. Google/OAuth

- [ ] If Google login is enabled, confirm it does not show the manual email
  confirmation pending screen.
- [ ] If the Google user has no username, confirm it shows only
  `Kullanıcı adını seç` before the main app.
- [ ] If Google login is disabled or postponed for this build, mark this item as
  not applicable.

## Android Deep Link Expectations

- `matchaman://auth/callback` parses as scheme `matchaman`, host `auth`, path
  `/callback`.
- `matchaman://reset-password` parses as scheme `matchaman`, host
  `reset-password`, with no required path.

If a link opens the browser instead of the app, check
`android/app/src/main/AndroidManifest.xml` and Supabase URL Configuration.
