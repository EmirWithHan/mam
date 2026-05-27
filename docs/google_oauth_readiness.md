# Google OAuth Readiness

Google OAuth is configured through Supabase Auth.

## Checklist

- Confirm Supabase Google provider is enabled.
- Check Google OAuth consent screen status.
- Confirm authorized redirect URI matches the Supabase callback URL.
- Keep local web testing on port 3000 when using the documented localhost callback.
- Add production domains and redirect URLs before public launch.
- Do not commit Google client secrets.

## Local Web Reminder

Use port 3000 for local OAuth callback testing:

```bash
flutter run -d chrome --web-port 3000 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
