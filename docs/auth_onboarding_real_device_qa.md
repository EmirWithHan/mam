# Auth + Username Onboarding Real Device QA

Date: 2026-06-06

Use this checklist before distributing the Android beta APK. Do not commit real
Supabase values, passwords, reset links, confirmation links, or APK files.

## Debug APK Build

Use placeholders in docs and real values only in your local terminal or CI
secrets.

```powershell
flutter build apk --debug ^
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" ^
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

APK path:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## 1. Fresh Install

- [ ] Uninstall the old app from the Android device.
- [ ] Clear app data if you are reusing an installed beta build.
- [ ] Install the new debug APK.
- [ ] Register with an unused real email address.
- [ ] Tap register and do not press login manually.
- [ ] Confirm the confirmation email arrives.
- [ ] Confirm `E-postanı doğrula` appears.
- [ ] Confirm `E-posta adresine doğrulama bağlantısı gönderdik.` appears.
- [ ] Confirm no OTP or 6-digit code input appears.
- [ ] Confirm the main app is blocked before email confirmation.

## 2. Email Confirmation

- [ ] Open the confirmation email on the phone.
- [ ] Tap the confirmation link.
- [ ] Confirm the app opens from `matchaman://auth/callback`.
- [ ] Confirm `Kullanıcı adını seç` appears if the profile has no username.

## 3. Username Onboarding

- [ ] Leave username empty and confirm a Turkish validation error appears.
- [ ] Enter an invalid username with spaces and confirm it fails.
- [ ] Try a duplicate username and confirm a Turkish error appears.
- [ ] Enter a valid username and tap `Devam et`.
- [ ] Confirm the user enters the main app.

## 4. Optional Profile

- [ ] Confirm the user can use the app after username only.
- [ ] Open Profile or Settings and confirm full profile editing is still
  reachable.
- [ ] Confirm photo, bio, city, district, gender, birth date, phone, and
  business information are not forced during first onboarding.

## 5. Login

- [ ] Log out.
- [ ] Log in with a verified user that already has a username.
- [ ] Confirm the app opens the main app directly.
- [ ] Log in with an unverified user.
- [ ] Confirm the app shows `E-posta adresini doğrulaman gerekiyor.`
- [ ] Confirm no raw Supabase exception is shown.

## 6. Password Reset

- [ ] Tap `Şifremi unuttum`.
- [ ] Enter a valid email and tap `Bağlantı gönder`.
- [ ] Confirm `Şifre sıfırlama bağlantısı e-postana gönderildi.` appears.
- [ ] Open the reset email on the phone.
- [ ] Confirm the app opens `Yeni şifre belirle` from
  `matchaman://reset-password`.
- [ ] Enter matching new passwords.
- [ ] Tap `Şifreyi güncelle`.
- [ ] Confirm `Şifren güncellendi.` appears.
- [ ] Log in with the new password.

## 7. Regression

- [ ] Events loads.
- [ ] Home loads.
- [ ] Profile loads.
- [ ] User search loads.
- [ ] Settings loads.
- [ ] Auth and onboarding screens have no yellow/black overflow at common phone
  sizes.

## Notes

- No Firebase or push notification setup is part of this QA pass.
- No Supabase `service_role` key should appear in Flutter code, logs, docs, or
  scripts.
- If a migration is added in a future pass, push it manually with:

```powershell
npx supabase db push
```
