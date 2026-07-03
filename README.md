# Akanzi

A social sports and events Flutter app.

## Demo Docs

- [Demo data plan](docs/demo_data_plan.md)
- [Manual demo flow](docs/demo_flow.md)
- [Closed beta checklist](docs/closed_beta_checklist.md)
- [Known limitations](docs/known_limitations.md)
- [Store readiness precheck](docs/store_readiness_precheck.md)
- [Manual QA checklist](docs/manual_qa_checklist.md)

## Release / Beta Docs

- [Release readiness audit](docs/release_readiness_audit.md)
- [Privacy and data requirements](docs/privacy_and_data_requirements.md)
- [Facebook / Meta readiness](docs/facebook_meta_readiness.md)
- [Google OAuth readiness](docs/google_oauth_readiness.md)
- [Apple login readiness](docs/apple_login_readiness.md)
- [Android release checklist](docs/android_release_checklist.md)
- [iOS release checklist](docs/ios_release_checklist.md)
- [Web beta checklist](docs/web_beta_checklist.md)
- [Build commands](docs/build_commands.md)
- [Launch blockers](docs/launch_blockers.md)

## Development

Run with Supabase values supplied by `--dart-define` or local tooling. Do not
commit Supabase keys, OAuth secrets, signing files, or service role keys.

```bash
flutter pub get
flutter analyze
flutter test
```
