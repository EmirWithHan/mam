# Internal Test Prep

Date: 2026-06-04

## Status

Match A Man is ready to prepare for controlled internal Android testing from
Windows. iOS testing remains a Mac/Xcode follow-up. Do not promise push
notifications, Apple login, payments, real OTP, or production abuse controls to
testers.

## Platform Safety Notes

- Client runtime code does not use `dart:io` or Android-only platform APIs.
- Image picking uses Flutter `image_picker` and now shows a friendly error if
  gallery access fails.
- Location lookup uses `geolocator` permission checks and shows friendly errors
  from the create event flow.
- iOS `Info.plist` includes photo library and location permission text.
- Camera permission is not declared because camera capture is not implemented.
- No platform-specific filesystem path assumptions were found in client runtime
  code.

## Build Commands

Android on Windows:

```bash
flutter build apk --debug
```

iOS later on Mac:

```bash
flutter build ios --debug --no-codesign
```

Real iOS simulator testing, device testing, TestFlight, and store signing
require a Mac with Xcode and an Apple Developer account.

## Test Accounts

Create these accounts in the test Supabase project. Do not document or commit
passwords, service keys, OAuth secrets, or database credentials.

- Normal user A: completed public profile.
- Normal user B: completed public profile.
- Private user: completed profile with private account enabled.
- Business applicant: normal user with no active business account.
- Approved business user: user with an active approved business account.
- Admin user: user present in `admin_users`.

## Admin Account Requirement

The admin user must be configured server-side in the test database. Normal users
must not see business application details, admin feedback lists, or approval
actions. Admin approval/reject should be tested with a real pending business
application.

## Android Test Steps

1. Build the debug APK with `flutter build apk --debug`.
2. Install on at least one small Android device and one larger Android device.
3. Start with a fresh install and no active session.
4. Run the smoke checklist below.
5. Record device model, Android version, app build, tester account, and any
   screenshots/videos for failures.

## iOS Test Steps Placeholder

1. Use a Mac with Xcode and the same branch/commit.
2. Confirm bundle ID ownership for `com.matchaman.app`.
3. Run `flutter build ios --debug --no-codesign`.
4. Configure signing only in the local Xcode/Apple Developer setup.
5. Test on iOS simulator and at least one real iPhone before TestFlight.
6. Verify photo library and location permission prompts appear only when those
   flows are used.

## Normal User Test Flow

1. Register or log in as normal user A.
2. Complete profile.
3. Open feed and create a post with a gallery image.
4. Open events, create a normal event, and confirm it appears.
5. Log out and reopen the app to verify session restore when expected.

Expected result: no white screen, no raw Supabase/Postgrest error, no clipped
primary button, and no permission prompt before the related action.

## Business Account Test Flow

1. Log in as business applicant.
2. Submit a business application from settings.
3. Log in as admin user.
4. Approve the application.
5. Log in as the approved business user.
6. Create a business event.
7. Delete the business account and confirm future business visibility is safe.

Expected result: normal users cannot approve/reject, deleted businesses are not
public/sponsored, and the account returns to normal user mode after delete.

## Private Profile And Follow Request Test Flow

1. Log in as private user and enable private profile.
2. Log in as normal user A.
3. Search for the private user.
4. Send a follow request.
5. Verify public-only profile state before approval.
6. Approve/reject from the private user's side or notifications if available.

Expected result: private gallery/events stay hidden before approval, and email,
phone, auth metadata, and admin/moderation fields are never shown.

## Username Search Test Flow

1. Search with fewer than two characters.
2. Search by username.
3. Search by username tag format if available.
4. Open a result profile.
5. Follow/add friend for a public user.
6. Verify self result is disabled or labeled as the current user.

Expected result: search does not spam requests, routes are stable, and private
data is not exposed in results.

## Feedback Test Flow

1. Open Settings.
2. Open feedback.
3. Submit rating/category with optional message.
4. Try invalid input and verify friendly validation.
5. Log in as admin and verify feedback review path if available.

Expected result: submit disables duplicate loading, errors are friendly, and no
raw database policy text appears.

## Smoke Test Checklist

- Login.
- Feed opens.
- Events open.
- Create event.
- Join event.
- Username search.
- Add friend/follow.
- Business application.
- Admin approve.
- Business delete.
- Feedback.
- Logout/session restore.

## Responsive Device Checklist

Run core navigation, auth, forms, event detail, search, feedback, and settings
on:

- 320x568
- 360x640
- 390x844
- 393x852
- 412x915
- 430x932
- 600x960

Check:

- No RenderFlex overflow.
- No infinite width error.
- No white screen.
- No clipped primary button.
- Keyboard does not hide the active input or submit button.
- Long usernames, event titles, captions, buttons, and chips wrap or ellipsize
  cleanly.

## Remaining TODOs

- Run Android APK on real devices.
- Run iOS build and simulator/device tests on Mac/Xcode.
- Prepare TestFlight later with Apple Developer signing.
- Verify Supabase staging RLS/RPC/storage behavior with real test accounts.
- Record manual QA evidence before closed beta.
