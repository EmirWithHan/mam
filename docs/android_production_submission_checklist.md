# Android Production Submission Checklist

Use this only after `docs/public_launch_hard_gate.md` passes.

1. Confirm launch candidate.
2. Bump `pubspec.yaml` versionCode if needed.
3. Run checks:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

4. Build signed AAB:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

5. Upload to Google Play production or promote from closed testing if
   appropriate.
6. Confirm release notes.
7. Confirm rollout percentage. Recommended: start staged rollout if available.
8. Review warnings.
9. Submit for review.
10. Monitor review status.
11. After approval, monitor crashes/feedback.

## Rules

- Do not commit AAB output.
- If versionCode already used, increment and rebuild.
- If Play asks for additional declarations, answer based on actual app behavior
  only.
- Do not claim unsupported Firebase/push, payment, tracking, or safety
  guarantees.
