# TestFlight Plan

## Purpose

TestFlight will be used for iOS beta testing before App Store release.

## Internal Testing

Internal testing is for App Store Connect team users. Use it first to confirm
the signed IPA installs, launches, and reaches the main flows.

## External Testing

External testing is for real beta users. Apple requires beta App Review before
external testers can install the build. Testers install through the TestFlight
app, not from a raw APK/IPA file.

## Tester Plan

- Collect iPhone tester emails outside the repository.
- Target at least 5-10 iOS testers for early beta.
- Ask each tester for device model and iOS version.
- Use the same short bug report template as Android:
  `docs/beta_bug_report_short_template.md`.
- Do not collect passwords, tokens, reset links, or confirmation links.

## iOS Test Flows

- Install the TestFlight build.
- Register with a real email.
- Confirm the email link.
- Choose username.
- Confirm Home loads.
- Confirm Events loads.
- Confirm Profile loads.
- Confirm Search loads.
- Confirm Settings loads.
- Confirm forgot password works.
- Confirm account deletion/request path opens.
- Confirm the app icon is Match A Man, not the Flutter logo.
- Confirm there is no visible overflow on common iPhone sizes.
- Confirm no raw Supabase/Postgrest error appears in the UI.

## Known iOS Risks

- Signing/certificates/provisioning profile setup.
- Deep links opening Safari instead of the app.
- Photo permission behavior if image upload is tested.
- Location permission behavior if event location autofill is tested.
- Keyboard and safe-area layout overflow.
- App Review metadata issues.
- Account deletion/privacy URL readiness.

## Related Build And Upload Docs

- Apple Developer readiness:
  `docs/ios_apple_developer_readiness_checklist.md`.
- MacInCloud build day runbook:
  `docs/macincloud_ios_build_day_runbook.md`.
- Bundle ID and signing notes:
  `docs/ios_bundle_id_and_signing_notes.md`.
- iOS deep link checklist:
  `docs/ios_deep_link_test_checklist.md`.
- App Store Connect metadata prep:
  `docs/app_store_connect_metadata_prep.md`.
- Internal TestFlight checklist:
  `docs/testflight_internal_beta_checklist.md`.
- MacInCloud risk checklist:
  `docs/macincloud_risk_checklist.md`.
- TestFlight upload day gate:
  `docs/ios_testflight_upload_day_gate.md`.
- MacInCloud session checklist:
  `docs/macincloud_session_checklist.md`.
- Xcode signing checklist:
  `docs/xcode_signing_checklist.md`.
- IPA upload troubleshooting:
  `docs/ios_ipa_upload_troubleshooting.md`.
- First TestFlight build checklist:
  `docs/testflight_first_build_checklist.md`.
- App Store review notes draft:
  `docs/app_store_review_notes_draft.md`.

Signed IPA build remains a manual macOS/Xcode step and must not commit IPA
output, Apple signing assets, or real Supabase values.
