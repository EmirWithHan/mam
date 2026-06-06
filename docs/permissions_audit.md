# Permissions Audit

Date: 2026-06-06

## Android

File inspected:

```text
android/app/src/main/AndroidManifest.xml
```

| Permission | Used or unused | Where requested/used | Why needed | User-facing explanation | Action |
| --- | --- | --- | --- | --- | --- |
| `android.permission.INTERNET` | Used | Supabase Auth/Database/Storage/Realtime, map links/network images | Required for backend access and media | App needs internet for login, events, feed, profiles, uploads | Keep |
| `android.permission.ACCESS_FINE_LOCATION` | Used, action-triggered | `CreateEventPage` -> `LocationService.getCurrentPosition()` | Optional current-location helper for event location | Used only when user taps location helper while creating an event | Keep for now |
| `android.permission.ACCESS_COARSE_LOCATION` | Used, action-triggered | Same location helper path | Allows approximate location fallback | Used only when user taps location helper while creating an event | Keep for now |

Android permissions not declared:

- Camera: not declared; camera capture is not implemented.
- Notification: not declared; Firebase/FCM push is postponed.
- Broad storage/media permissions: not declared. Image picking uses
  `image_picker`; verify Android 13+ picker behavior during device QA.

## iOS

File inspected:

```text
ios/Runner/Info.plist
```

| Permission text | Used or unused | Where requested/used | Why needed | Current description | Action |
| --- | --- | --- | --- | --- | --- |
| `NSLocationWhenInUseUsageDescription` | Used, action-triggered | `CreateEventPage` location helper | Optional current-location helper for event location | `Konumun, etkinlik konumunu otomatik doldurmak icin kullanilir.` | Keep; consider Turkish character polish later |
| `NSPhotoLibraryUsageDescription` | Used, action-triggered | Profile avatar picker and create post image picker | User-selected avatar/post image upload | `Galerinden profil avatarini veya paylasim fotografini secmek icin kullanilir.` | Keep; consider Turkish character polish later |

iOS permissions not declared:

- Camera: not declared; camera capture is not implemented.
- Push notification permission: not declared; Firebase/FCM push is postponed.

## Permission Behavior Notes

- Location must not be requested on app startup. Current code requests it only
  when the create-event location helper is tapped.
- Photo library must not be requested on app startup. Current code requests it
  only when the user taps avatar/post image selection.
- Do not add camera permission unless camera capture is actually implemented.
- Do not add notification permission until push notifications are explicitly
  implemented.
- Do not add broad storage permissions unless a future media flow requires them
  and modern platform pickers cannot support the flow.

## Manual QA Checklist

- [ ] Fresh install does not request location immediately.
- [ ] Fresh install does not request photo library immediately.
- [ ] Create event location helper asks for location only after tap.
- [ ] Denied location shows friendly Turkish copy.
- [ ] Avatar image picker asks for photo access only after tap.
- [ ] Create post image picker asks for photo access only after tap.
- [ ] No camera permission appears.
- [ ] No push notification permission appears.
- [ ] Play Console permissions match the manifest in the release build.
