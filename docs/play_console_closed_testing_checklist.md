# Play Console Closed Testing Checklist

Date: 2026-06-06

## Purpose

This document prepares Match A Man for Google Play closed testing. It does not
mean the app is ready for public launch.

Closed testing is for controlled Android tester feedback before production.
Newer personal Google Play developer accounts may need at least 12 opted-in
testers for 14 continuous days. Confirm the current requirement inside Play
Console before planning launch dates.

## Required Play Console Setup

- [ ] Google Play Developer account created.
- [ ] App created in Play Console.
- [ ] App name set to Match A Man.
- [ ] Default language set to Turkish if launch is Turkish-first.
- [ ] App category selected.
- [ ] Contact email prepared.
- [ ] Privacy policy URL prepared.
- [ ] Account deletion web URL prepared.
- [ ] Data Safety draft prepared.
- [ ] Content rating questionnaire prepared.
- [ ] Target audience section prepared.
- [ ] Ads declaration prepared.
- [ ] App access instructions prepared if login is required.
- [ ] Testing track created.

## Closed Testing Track Setup

- [ ] Create closed testing track.
- [ ] Choose tester access method: email list or Google Group.
- [ ] Add at least 12 reliable Android testers if the personal-account
  requirement applies.
- [ ] Keep testers opted-in continuously for at least 14 days if required.
- [ ] Share opt-in link.
- [ ] Make sure testers actually install and use the app.
- [ ] Prepare tester feedback channel: WhatsApp group, email, Google Form, or
  issue list.
- [ ] Keep a tester status sheet.

## Tester List Tracking

| Field | Value |
| --- | --- |
| Tester name |  |
| Tester email |  |
| Device model |  |
| Android version |  |
| Opt-in date |  |
| Installed app |  |
| First test done |  |
| Day 7 check |  |
| Day 14 check |  |
| Feedback received |  |
| Still opted-in |  |
| Notes |  |

Use `docs/templates/closed_test_tester_status_sheet.csv` for spreadsheet import.
Do not commit real tester emails.

## App Bundle Upload Checklist

- [ ] Signed release AAB generated.
- [ ] AAB built with correct `--dart-define` values.
- [ ] `versionCode` increased.
- [ ] `versionName` correct.
- [ ] App icon correct, no Flutter logo.
- [ ] App label correct: Match A Man.
- [ ] No debug banner.
- [ ] No raw secrets.
- [ ] No debug-only screens.
- [ ] No broken legal/account deletion links.
- [ ] No English placeholder texts on main screens.
- [ ] No yellow/black overflow on screenshot screens.

Current repo reference:

- `pubspec.yaml` version: `1.0.0+1`.
- Android label: `Match A Man`.
- Android icon: `@mipmap/ic_launcher`.

## Store Listing Checklist

- [ ] Short description ready.
- [ ] Full description ready.
- [ ] App icon ready.
- [ ] Feature graphic ready or TODO clearly marked.
- [ ] Phone screenshots ready.
- [ ] Screenshots contain no real private data.
- [ ] Screenshots do not show broken UI.
- [ ] Screenshots do not show admin/debug screens.
- [ ] Claims are launch-safe and not exaggerated.

## Policy Checklist

- [ ] Privacy policy URL exists.
- [ ] Account deletion web URL exists.
- [ ] In-app account deletion/request path exists.
- [ ] Data Safety answers match real app behavior.
- [ ] Content rating completed honestly.
- [ ] Target audience selected correctly.
- [ ] App access instructions written if reviewer needs login.
- [ ] Login test account prepared if needed.
- [ ] No fake claim like "100% güvenli".
- [ ] No dating-app positioning if app is sports/social event app.
- [ ] No copyrighted media in screenshots/assets.

## Login/App Access Instructions For Play Review

Reviewer instructions draft:

- This app requires login to access main features.
- Test account email: `REVIEWER_TEST_EMAIL_PLACEHOLDER`
- Test account password: `REVIEWER_TEST_PASSWORD_PLACEHOLDER`
- Do not commit real credentials.
- Login steps:
  1. Open app.
  2. Tap `Giriş Yap`.
  3. Enter test credentials.
  4. Open `Ana Akış`, `Etkinlikler`, `Profil`, and `Ayarlar`.
- If account deletion is tested: `Ayarlar` -> `Hesabımı sil`.

Real reviewer credentials must be entered only in the Play Console private app
access section. Do not commit the reviewer password to the repo.

## 14-Day Closed Testing Operating Plan

### Day 0

- Upload AAB.
- Add testers.
- Send opt-in link.
- Ask testers to install.

### Day 1

- Confirm at least 12 testers opted-in if required.
- Confirm app opens on tester devices.

### Days 2-6

- Ask testers to try core flows: login, home/feed, events, event detail, create
  event, profile, settings, search/social, feedback, and account deletion
  request only with a disposable test account.
- Collect screenshots/videos for bugs.

### Day 7

- Mid-test bug sweep.
- Fix blockers.
- Upload new build if needed.

### Days 8-13

- Verify fixes.
- Keep testers opted-in.
- Collect final feedback.

### Day 14

- Confirm testing duration.
- Prepare production access answers if needed.
- Do not rush production if blockers remain.

## Production Access Preparation Notes

Prepare a short internal summary before requesting production:

- Closed test feedback received.
- Bugs found and fixed.
- Tester engagement notes.
- Known issues that remain.
- Why the app is ready or not ready for production.

Do not claim Play approval is guaranteed.
