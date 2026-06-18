# iOS Privacy and Permissions Audit

## Current Info.plist Permission Keys

| Permission key | Status | Why it exists | Store form note |
| --- | --- | --- | --- |
| `NSPhotoLibraryUsageDescription` | Used | Gallery/photo selection is supported for profile avatar or shared image flows through `image_picker`. | Declare photo library access if screenshots or App Store privacy forms ask about user-selected photos. |
| `NSLocationWhenInUseUsageDescription` | Used | Event location autofill can use device location through the location packages. | Declare location access if enabled in release builds. |

Current Turkish-facing permission text is present in `ios/Runner/Info.plist`.

## Permissions Not Present

- Camera permission is not declared. Add `NSCameraUsageDescription` only if a
  camera capture flow is actually used.
- Push notification permission is not declared. Firebase/push is postponed.
- App Tracking Transparency is not declared. Do not add ATT unless tracking is
  actually implemented.

## App Store Privacy Notes

- Do not claim tracking if no tracking exists.
- Do not add push notification declarations because push is not implemented.
- Keep Supabase Auth as the source of truth.
- Review privacy answers for auth data, profile data, user content, feedback,
  reports, photos, and location before App Store submission.

## Manual Verification

- Test profile/photo flows on a real iPhone or simulator.
- Test event location flows if enabled for beta.
- Confirm permission prompts are clear enough for Turkish beta testers.
- Confirm denying a permission does not crash the app.
