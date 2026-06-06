# Store Readiness

## App Name

Match A Man

## Short Description Draft

Find and join local sports and social events with people nearby.

Turkish Play Store listing draft exists:
`docs/play_store_listing_draft_tr.md`.

## Long Description Draft

Match A Man is an event-centered social sports app. Discover local football,
basketball, tennis, running, and social activity events, request to join, chat
after approval, and share moments from events on your profile.

The app is designed for sports, activities, trust, and real-life social plans.
It is not a dating app.

Current in-app user-facing copy is locked to Turkish for MVP screens. Store
listing copy may still be localized separately before submission.

MVP safety tools include profile privacy, follow requests, report actions,
blocking, admin business review, feedback, and trust-score signals for event
behavior.

## Keywords Draft

sports, events, social sports, local activities, football, basketball, tennis,
running, meetup, group events, activity friends

## Screenshot Checklist

- Auth screen with Match A Man branding.
- Events list with sport/event cards.
- Event detail with join request flow.
- Create event form.
- Feed/home with event-linked posts.
- Profile with trust score and activity.
- Social/search screen.
- Settings with privacy, report/block, feedback, and legal links.

Detailed screenshot plan exists: `docs/play_store_screenshot_plan.md`.
Screenshot capture checklist exists: `docs/screenshot_capture_checklist.md`.
Feature graphic plan exists: `docs/play_store_feature_graphic_plan.md`.
Store claim safety checklist exists: `docs/store_claim_safety_checklist.md`.
Android store asset folders are prepared under `store_assets/android/`.

Remaining store visual TODOs:

- Capture final Android phone screenshots.
- Export final Play Store feature graphic.
- Export final Play Store icon assets.
- Upload final listing and assets to Play Console.

## Privacy And Legal TODO

- Play Store Data Safety developer draft created:
  `docs/play_store_data_safety_draft.md`.
- Permissions audit created: `docs/permissions_audit.md`.

- In-app MVP legal drafts now exist for Kullanım Şartları, Gizlilik
  Politikası, Topluluk Kuralları, and Etkinlik Güvenliği ve Sorumluluk Reddi.
- In-app account deletion request/deactivation path exists for closed beta.
- Public web deletion page plan/template exists:
  `docs/account_deletion_web_page_plan.md` and
  `docs/web_templates/account_deletion_request.html`.
- Replace MVP legal draft text with professionally reviewed privacy policy,
  terms, community rules, event safety/disclaimer, and support/account deletion
  copy before production release.
- Prepare public privacy policy URL for Play Console and App Store Connect.
- Prepare public data deletion request URL or support process; see
  `docs/account_deletion_web_resource.md`.
- Confirm store data safety/privacy nutrition answers for auth, profile,
  location, photos, user content, reports, feedback, and analytics if added.
- Public launch should not proceed until privacy review, Data Safety answers,
  permission declarations, and account/data deletion requirements are clear.
- See `docs/legal_todo.md`.

## Known Blockers Before Real Store Submission

- Configure release signing for Android and iOS.
- Confirm final ownership of Android application ID `com.matchaman.app`.
- Confirm final ownership of iOS bundle ID `com.matchaman.app`.
- Apply and verify Supabase migrations in staging/production.
- Run manual QA for auth/session restore, event creation, feed, profile,
  report/block, business approval/delete, feedback, and legal links.
- Prepare final app screenshots and review store listing copy.
- Final feature graphic and Play Console upload remain TODO.
- Prepare reviewer test account instructions without exposing secrets.
- Review Apple Sign in requirement if third-party social login remains enabled
  on iOS.
- Confirm production support contact and account deletion process.
- Finalize backend/Auth deletion, retention rules, and public web deletion URL
  before public launch.
- Real hosted account/data deletion URL must exist before Play Store
  submission. If using manual email review, Play Console wording must not
  overclaim automated deletion.
- Verify in-app notification/feed refresh behavior on real devices while the
  app is open. Firebase/push remains intentionally unimplemented.

## Android Release Build

Play Store upload uses the release AAB. Build it with dart-defines and
placeholder-only docs/scripts:

```powershell
flutter build appbundle --release `
  --dart-define=SUPABASE_URL="YOUR_SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
```

Signing config and keystore setup will be handled separately. Do not commit
keystores, real Supabase values, service-role keys, or other secrets.
