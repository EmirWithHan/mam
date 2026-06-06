# Play Store Screenshot Plan

Date: 2026-06-06

Use phone portrait screenshots. Do not create fake screenshots or show features
that are not stable in the submitted build.

## 1. Açılış / Marka Ekranı

- Purpose: Show Match A Man identity.
- Suggested headline: Sporla sosyalleş
- Suggested subtext: Etkinlikleri keşfet, ekibini bul.
- Capture account type: logged out or fresh launch.
- Required data state: clean app start with Match A Man logo visible.
- First closed beta: required.
- Risk notes: no debug banner, no loading error, no unrelated branding.

## 2. Ana Akış

- Purpose: Show posts and social activity.
- Suggested headline: Akışı takip et
- Suggested subtext: Gönderilerle topluluk hareketini gör.
- Capture account type: normal user.
- Required data state: at least 2 clean sample posts with safe test users.
- First closed beta: required if feed is stable.
- Risk notes: no real private people/photos, no offensive content, no raw error.

## 3. Etkinlikler

- Purpose: Show finding sports/activity events.
- Suggested headline: Etkinlikleri keşfet
- Suggested subtext: Spor ve sosyal aktivitelerde yerini bul.
- Capture account type: normal user.
- Required data state: at least 2-3 sample events with dates/locations.
- First closed beta: required.
- Risk notes: event cards must not overflow; do not show hidden/deleted events.

## 4. Etkinlik Detayı

- Purpose: Show join/request flow and event info.
- Suggested headline: Ekibini tamamla
- Suggested subtext: Detayları incele, katılma isteği gönder.
- Capture account type: normal user.
- Required data state: one active event with realistic title, date, location,
  capacity, and participant state.
- First closed beta: required.
- Risk notes: no real address unless intended; no permission error.

## 5. Etkinlik Oluşturma

- Purpose: Show user can create events.
- Suggested headline: Kendi etkinliğini oluştur
- Suggested subtext: Saat, konum ve kapasiteyi belirle.
- Capture account type: normal user with completed profile.
- Required data state: form open with safe draft values or empty clean state.
- First closed beta: required if creation flow is stable.
- Risk notes: no keyboard covering critical UI; no yellow/black overflow.

## 6. Profil

- Purpose: Show public identity/profile.
- Suggested headline: Profilini güçlendir
- Suggested subtext: Etkinliklerin ve sosyal kimliğin bir arada.
- Capture account type: normal user.
- Required data state: clean profile with username, trust score, and safe sample
  activity.
- First closed beta: required.
- Risk notes: no real phone/email; no private personal photos without
  permission.

## 7. Sosyal / Kullanıcı Arama

- Purpose: Show finding people and social connection.
- Suggested headline: Toplulukla bağlantı kur
- Suggested subtext: Kullanıcı ara, takip et, etkinlik çevreni genişlet.
- Capture account type: normal user.
- Required data state: staged test accounts with non-personal usernames.
- First closed beta: required if search/follow state is stable.
- Risk notes: no private users exposed incorrectly; no raw backend messages.

## 8. İşletme / Organizasyon

- Purpose: Show business/event organizer side if stable.
- Suggested headline: Organizasyonunu tanıt
- Suggested subtext: İşletme hesabı başvurusu ile etkinliklerini yönet.
- Capture account type: approved business user or business applicant.
- Required data state: safe business profile/application state with no real
  phone/address unless intended.
- First closed beta: optional.
- Risk notes: show only if the business flow is stable; do not imply official
  verification unless actually approved by app rules.
