# Signed AAB Build Day Commands

Use real Supabase values only in your local terminal or secure CI secrets. Keep
docs/scripts placeholder-only.

## 1. Clean And Check

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

## 2. Build Debug APK For Last Own-Device Check

```powershell
flutter build apk --debug `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Install this build on your own Android phone and run
`docs/final_apk_smoke_test_checklist.md`.

## 3. Build Signed Release AAB

Requires local signing files:

```text
android/key.properties
android/app/upload-keystore.jks
```

Build:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## 4. Expected Output

```text
build/app/outputs/bundle/release/app-release.aab
```

## 5. Do Not Commit

- `build/`
- `app-release.aab`
- `android/key.properties`
- `android/app/upload-keystore.jks`
- Real dart-define values
- Signing passwords
