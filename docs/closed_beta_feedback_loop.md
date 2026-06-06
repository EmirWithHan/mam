# Closed Beta Feedback Loop

Date: 2026-06-06

## Goal

Use this document to collect clean bug reports and tester feedback during the
Android APK closed beta. Keep reports concrete: account, device, screen, exact
steps, screenshot/video, and approximate time.

No Firebase or push notifications are part of this feedback loop.

Related docs:

- `docs/bug_triage_system.md`
- `docs/real_device_test_matrix.md`
- `docs/beta_tester_message_tr.md`

## Tester Instructions

### Install APK

1. Download the APK shared by the team.
2. On Android, allow install from the selected file manager/browser if Android
   asks.
3. Tap the APK and install Match A Man.
4. Open the app and wait for the auth screen.

For modern Android phones, use the `arm64-v8a` release APK when available. If
the team sends a debug APK, expect it to be much larger.

### Log In

1. Use the test account email provided by the team.
2. Enter the password shared privately outside this repo.
3. Complete the profile if the app asks.
4. Do not share passwords in screenshots, chats, bug reports, or public places.

### Flows To Test

- Open Home/feed and scroll.
- Create/view a gönderi if your account is allowed.
- Open Events, scroll the list, search/filter, and open event detail.
- Create a normal etkinlik if your profile is complete.
- Send/join/leave event requests with another tester.
- Use kullanıcı arama and arkadaş ekleme/follow request flows.
- Open Social/chat if available for your events.
- Open Profile and Settings.
- Submit `Geri bildirim gönder` from Settings.
- Business testers: submit or verify işletme hesabı flows.
- Admin tester: approve/reject business applications and review feedback.

### How To Report Bugs

Send the report to the internal beta contact/channel with:

- One short title.
- The filled bug report template below.
- Screenshot or screen recording when possible.
- Exact account used.
- Approximate time of the issue.

If the app is unusable, send a video from opening the app until the failure.

### Screenshots/Videos To Send

- Screenshot of the broken screen.
- Short video for crashes, white screens, stuck loading, login issues, or flows
  with multiple steps.
- Include the whole screen when possible so device size and navigation state are
  visible.
- Do not include real passwords, private messages, phone numbers, or personal
  data from non-test accounts.

## Bug Report Template

```text
Title:
Device model:
Android version:
App build type: debug / release / unknown
Screen/page:
What user tried to do:
What happened:
Expected result:
Screenshot/video:
Approximate time:
User account used:
Severity: blocker / high / medium / low
Notes:
```

## Feedback Categories

- crash/white screen
- login/register
- feed/gönderi
- etkinlik
- arkadaş ekleme/kullanıcı arama
- işletme hesabı
- bildirim
- profil/ayarlar
- tasarım/taşma
- performans/yavaşlık
- öneri

## Internal Triage Rules

### BLOCKER

Use when the app is unusable, login is impossible, a core page is broken for
normal users, or testers cannot continue the beta pass.

Examples:

- App opens to white screen.
- Login/register cannot complete.
- Home, Events, Profile, Settings, or Notifications always fails.
- Repeated crash on startup or navigation.

### HIGH

Use when a main flow is broken but the app is still partly usable.

Examples:

- Event join/approval does not work.
- Feedback cannot be submitted.
- Business application submit/review fails.
- Search or profile opens fail for normal users.

### MEDIUM

Use when a workaround exists.

Examples:

- Manual refresh fixes stale state.
- One card layout is awkward but readable.
- A secondary action fails while the main flow works.

### LOW

Use for polish, text, small layout, or minor performance issues.

Examples:

- Typo or wording inconsistency.
- Small spacing issue.
- A long title truncates earlier than ideal but no action is blocked.

## Tester Message Draft

```text
Selam! Match A Man kapalı beta APK'sını test ediyoruz.

APK'yı telefona indirip kurabilir misin? Android izin isterse "bu kaynaktan yüklemeye izin ver" demen gerekebilir. Sana verdiğim test hesabıyla giriş yap.

Özellikle şunları dene:
- Ana sayfa/akış açılıyor mu?
- Etkinlikler listesi, etkinlik detayı ve katılma isteği çalışıyor mu?
- Profil, ayarlar, bildirimler ve kullanıcı arama açılıyor mu?
- Geri bildirim gönder ekranından yorum gönderebiliyor musun?
- Ekranda taşma, siyah/sarı çizgi, beyaz ekran veya donma oluyor mu?

Bir sorun görürsen lütfen ekran görüntüsü veya kısa video gönder. Mümkünse telefon modelini, Android sürümünü, hangi hesapla denediğini ve yaklaşık saati de yaz.

Bu beta sürüm; hata görmen normal. Ne kadar net ekran görüntüsü/video gönderirsen o kadar hızlı düzeltebiliriz. Teşekkürler!
```

## In-App Feedback

Existing feedback path:

```text
Settings > Geri Bildirim
```

The current app already has:

- Feedback page with rating, category, and message.
- Feedback provider/controller.
- Feedback service writing to `public.user_feedback`.
- Admin feedback list if the admin route is accessible.

Do not add a new feedback feature unless this existing screen/table/service is
broken.

## Internal Handling

- Keep raw tester messages in the internal channel/tool.
- Convert each actionable issue into one tracked task.
- Attach screenshots/videos to the task.
- Group duplicates by screen and root cause.
- Retest blocker/high fixes on a real Android device before sharing a new APK.
