# APK Beta Operating Plan

## Before Sending APK

1. Run `flutter analyze`.
2. Run `flutter test`.
3. Build the debug APK with dart-defines.
4. Install the APK on your own Android phone first.
5. Run the smoke test in `docs/final_apk_smoke_test_checklist.md`.
6. Confirm the app icon is Match A Man, not the Flutter logo.
7. Confirm email verification works.
8. Confirm username onboarding works.
9. Confirm core pages load: Ana Akış, Etkinlikler, Profil, Kullanıcı arama,
   Ayarlar.

## APK Build Command

```powershell
flutter analyze
flutter test
```

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## Copy Command

```powershell
copy build\app\outputs\flutter-apk\app-debug.apk "$env:USERPROFILE\Desktop\Match_A_Man_debug.apk"
```

## Send Method

- Send through WhatsApp as Document/File.
- Use a Google Drive link if WhatsApp size fails.
- Do not send the APK as image/media.
- Do not commit APK files to the repository.

## Tester Phases

### Phase 1

- 3 close testers.
- Goal: app opens, auth works, no blocker.

### Phase 2

- 8-12 testers.
- Goal: core flows and device variety.

### Phase 3

- 18-25 candidates for Play Store closed testing later.
- Goal: collect reliable Google Play tester emails privately.

## Stop Conditions

Do not expand the tester group if:

- App white screens.
- Signup/login is broken.
- Email confirmation is broken.
- Username onboarding is broken.
- Home, Events, or Profile is unusable.
- A data/privacy issue appears.

## First 3 Tester Docs

- Smoke test checklist: `docs/final_apk_smoke_test_checklist.md`
- Rollout plan: `docs/first_3_tester_rollout_plan.md`
- WhatsApp messages: `docs/first_3_tester_whatsapp_messages_tr.md`
- Bug intake: `docs/first_3_tester_bug_intake.md`
