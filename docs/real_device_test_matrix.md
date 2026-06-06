# Real Device Test Matrix

Date: 2026-06-06

Use this matrix during closed beta builds. Fill one row per device/build pass and
keep screenshots/videos linked from the related bug report.

## Device Matrix

| Device | OS version | Screen size | Tester | Build type | Install method | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Redmi / Xiaomi Android | TBD | TBD | TBD | debug/release | APK | NEW | Test startup, auth, Events, overflow |
| Samsung Android | TBD | TBD | TBD | debug/release | APK | NEW | Test permissions, keyboard, notifications |
| iPhone 13 or later | TBD | TBD | TBD | cloud/iOS build | TestFlight/manual later | POSTPONED | iOS cloud no-codesign build passed; device QA later |
| Small Android device if available | TBD | 320-360px width | TBD | split APK preferred | APK | NEW | Overflow and keyboard priority |
| Large Android device if available | TBD | 400px+ width | TBD | split APK preferred | APK | NEW | Tablet/large phone spacing |

Status values: `NEW`, `IN_PROGRESS`, `PASSED`, `FAILED`, `BLOCKED`,
`POSTPONED`.

## Screen Matrix

Track each screen with the columns below:

| Screen | Loads | No overflow | No raw error | Permission correct | Refresh/state correct | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Splash/startup | TBD | TBD | TBD | TBD | TBD | Confirm no white screen |
| Login | TBD | TBD | TBD | TBD | TBD | Keyboard and invalid password |
| Register | TBD | TBD | TBD | TBD | TBD | Duplicate/invalid email |
| Profile completion | TBD | TBD | TBD | TBD | TBD | Keyboard, avatar, location fields |
| Home/Akis | TBD | TBD | TBD | TBD | TBD | Feed load and scroll |
| Create Gonderi | TBD | TBD | TBD | TBD | TBD | Gallery permission and submit |
| Comments/Yorumlar | TBD | TBD | TBD | TBD | TBD | Load, submit, refresh |
| Events/Etkinlikler | TBD | TBD | TBD | TBD | TBD | Header scrolls away |
| Event detail | TBD | TBD | TBD | TBD | TBD | Host, participant, unrelated user |
| Create Etkinlik | TBD | TBD | TBD | TBD | TBD | Form, keyboard, submit |
| Join request | TBD | TBD | TBD | TBD | TBD | Pending/current state |
| Participant approval/reject | TBD | TBD | TBD | TBD | TBD | Host only |
| Social/Sosyal | TBD | TBD | TBD | TBD | TBD | Route opens |
| Username search/Kullanici ara | TBD | TBD | TBD | TBD | TBD | Public-safe fields |
| Profile/Profil | TBD | TBD | TBD | TBD | TBD | Own, public, private |
| Settings/Ayarlar | TBD | TBD | TBD | TBD | TBD | Logout, legal, feedback |
| Notifications/Bildirimler | TBD | TBD | TBD | TBD | TBD | Manual refresh fallback |
| Feedback/Geri bildirim | TBD | TBD | TBD | TBD | TBD | Submit, validation |
| Business application/Isletme basvurusu | TBD | TBD | TBD | TBD | TBD | Normal user allowed |
| Admin/Yonetici paneli | TBD | TBD | TBD | TBD | TBD | Admin only |
| Business delete/Isletme hesabimi sil | TBD | TBD | TBD | TBD | TBD | Owner only |
| Legal pages | TBD | TBD | TBD | TBD | TBD | Terms/privacy/community/safety |

## Flow Matrix

| Flow | Accounts | Status | Notes |
| --- | --- | --- | --- |
| Fresh install -> register -> profile completion | New normal user | NEW | Confirm no white screen or auth loop |
| Logout -> login -> session restore | Existing user | NEW | Test after app kill/reopen |
| Create post -> view in feed | Normal user | NEW | Confirm friendly upload errors |
| Comment on post | Two normal users | NEW | Confirm comments refresh |
| Create event -> view detail | Event-ready user | NEW | Confirm list/detail update |
| Join event from another account | User B + host | NEW | Confirm pending state |
| Approve/reject participant | Host + requester | NEW | Confirm host-only action |
| Search username -> add friend/follow | Two public users | NEW | Confirm no private fields |
| Private follow request | Public user + private user | NEW | Confirm notification/action state |
| Business application -> admin approve | Applicant + admin | NEW | Confirm one profile identity |
| Business user creates event | Approved business user | NEW | Confirm business-only fields |
| Business delete -> return to user | Business owner | NEW | Confirm future business events hidden |
| Feedback submit | Any logged-in user | NEW | Confirm `Geri bildirim` works |
| Notification appears/updates while app is open | Two users/host | NEW | Confirm realtime or manual fallback |

## Pass Notes

- Build:
- Tester:
- Device:
- Date/time:
- Supabase project:
- Accounts used:
- Failed screens:
- Failed flows:
- Linked bug IDs:
- Go/no-go:
