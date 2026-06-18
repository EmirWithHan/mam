# Play Console Upload Day Checklist

Use this for manual closed testing upload. Do not upload from code.

## Upload Steps

1. Open Play Console.
2. Select `Match A Man`.
3. Go to Testing -> Closed testing.
4. Create/select closed testing track.
5. Upload `build/app/outputs/bundle/release/app-release.aab`.
6. Wait for processing.
7. Review errors/warnings.
8. Add release notes from `docs/play_closed_test_release_notes_final_tr.md`.
9. Confirm app access instructions.
10. Confirm Data Safety.
11. Confirm privacy policy URL.
12. Confirm account deletion URL.
13. Confirm content rating.
14. Confirm target audience.
15. Add testers/email list or Google Group privately.
16. Save changes.
17. Review release.
18. Roll out to closed testing.
19. Copy opt-in link.
20. Send opt-in message to testers.

## If Play Console Blocks Upload

- VersionCode already used: bump `pubspec.yaml` versionCode and rebuild.
- Signing warning: follow Play App Signing instructions and verify
  `android/key.properties` plus `android/app/upload-keystore.jks`.
- App access warning: fill reviewer credentials privately in Play Console.
- Privacy/account deletion warning: finish live URLs before rollout.
- Data Safety warning: complete the form based on actual app behavior.

## Do Not Commit

- AAB output
- Keystore files
- `key.properties`
- Tester emails
- Reviewer passwords
- Real Supabase values
