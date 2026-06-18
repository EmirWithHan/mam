# Play Pre-Upload Blocker Checklist

Use this before uploading a signed AAB to the Play Console closed testing track.

## Must Fix Before Closed Test Upload

- [ ] App does not open.
- [ ] Login/register is broken.
- [ ] Email confirmation is broken.
- [ ] Username onboarding is broken.
- [ ] Home is broken.
- [ ] Events is broken.
- [ ] Profile is broken.
- [ ] App icon still shows the Flutter logo.
- [ ] App label is not `Match A Man`.
- [ ] Raw secret is committed.
- [ ] `android/key.properties` is committed.
- [ ] Keystore is committed.
- [ ] Debug APK is being used instead of signed AAB.
- [ ] Reviewer login credentials are missing from Play Console private app
  access.
- [ ] Data Safety is incomplete.
- [ ] Content Rating is incomplete.

## Must Fix Or Clearly Document Before Closed Test Upload

- [ ] Privacy policy URL missing.
- [ ] Account deletion path/link missing or undocumented.
- [ ] App access instructions do not explain login.
- [ ] Store listing claims imply 100% safety, official supervision, or dating
  positioning.
- [ ] Screenshots contain real private user data.

## Can Be Documented For Public Launch

- [ ] Final marketing screenshots still need polish.
- [ ] Public legal text needs final legal review.
- [ ] iOS/TestFlight is not active yet.
- [ ] Firebase/push notifications are postponed.
- [ ] Production support/account deletion process needs final hosted URL.

Do not upload until all must-fix blockers are resolved.
