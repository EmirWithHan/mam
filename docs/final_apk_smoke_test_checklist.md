# Final APK Smoke Test Checklist

Use this before sending the APK to the first 3 close Android testers.

## Build Info

- Tester: developer/owner
- Device:
- Android version:
- Build date:
- Build type: debug APK
- Supabase environment:
- Result: PASS/FAIL

## Checklist

- [ ] Install APK.
- [ ] Open app.
- [ ] Supabase initializes with dart-defines.
- [ ] Register with a brand-new email.
- [ ] Verification email arrives.
- [ ] App immediately shows `E-postanı doğrula`.
- [ ] Unverified user cannot enter the main app.
- [ ] Verification link opens the app or at least verifies the account.
- [ ] Verified login/session shows `Kullanıcı adını seç` when username is
  missing.
- [ ] Username save succeeds.
- [ ] User enters main app after username.
- [ ] Home opens.
- [ ] Events opens.
- [ ] Event detail opens.
- [ ] Create opens.
- [ ] Social opens.
- [ ] Profile opens.
- [ ] Search opens.
- [ ] Settings opens.
- [ ] Forgot password flow opens and sends link.
- [ ] Logout/login works.
- [ ] App icon is not the Flutter logo.
- [ ] App label is `Match A Man`.
- [ ] No obvious yellow/black overflow on auth, onboarding, or core screens.
- [ ] No raw Supabase/Postgrest exception is shown to the user.
- [ ] No secrets are committed.

## Hard Gate

If any auth/onboarding item from install through entering the main app fails,
do not send the APK to testers.

```text
APK_BETA_READY = yes/no
```

## Notes

- Do not commit the APK.
- Do not commit tester emails.
- Do not commit passwords or real Supabase values.
- Firebase/push remains intentionally unimplemented.
