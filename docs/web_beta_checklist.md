# Web Beta Checklist

## Current Status

- Web title: `MaM`
- Web manifest name: `MaM`
- Web manifest icons exist at 192 and 512 sizes, including maskable variants.
- OAuth callback route: `/auth/callback`
- Local OAuth callback expectation: `http://localhost:3000/auth/callback`

## Local Command

```bash
flutter run -d chrome --web-port 3000 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Redirect URLs

- Add localhost redirect URLs in Supabase for web testing.
- Add production domain redirect URLs before public launch.
- Keep Supabase URL/anon key supplied by `--dart-define` or CI secrets.
- Do not hardcode Supabase secrets.

## Known Browser Limitations

- Real Google/Facebook OAuth depends on provider dashboard state.
- Browser storage/session behavior can vary by browser privacy settings.
- Production hosting domain and HTTPS setup are still required before public launch.
