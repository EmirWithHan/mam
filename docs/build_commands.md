# Build Commands

Never commit secrets. Use local environment variables, `--dart-define`, or CI secrets later. Do not use the Supabase `service_role` key in any client build.

## Development Web

```bash
flutter run -d chrome --web-port 3000 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Analyze And Test

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

## Android Debug Build

```bash
flutter build apk --debug --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Android Release Placeholder

```bash
flutter build appbundle --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## iOS Release Placeholder

```bash
flutter build ipa --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
