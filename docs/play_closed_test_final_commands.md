# Play Closed Test Final Commands

Use real Supabase values only locally or in secure CI secrets.

## Analyze And Test

```powershell
flutter analyze
flutter test
```

## Build Signed AAB

Run only after local signing files exist:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

## Expected Output

```text
build/app/outputs/bundle/release/app-release.aab
```

## Do Not Commit

- Build outputs
- `android/key.properties`
- Keystore files
- Real dart-defines
- Real Supabase values
- Reviewer passwords
- Tester emails
