# Play Reviewer Instructions Draft

Date: 2026-06-06

Do not commit real reviewer credentials. Enter the real reviewer login only in
the Play Console private app access section.

## Turkish

Match A Man, spor ve sosyal aktivite etkinlikleri için geliştirilmiş bir
topluluk uygulamasıdır. Flört/dating uygulaması değildir.

Uygulamanın ana özelliklerini test etmek için giriş yapılması gerekir.

Test hesabı:

- E-posta: `REVIEWER_TEST_EMAIL_PLACEHOLDER`
- Şifre: `REVIEWER_TEST_PASSWORD_PLACEHOLDER`

Giriş adımları:

1. Uygulamayı açın.
2. `Giriş Yap` ekranına gidin.
3. Test e-postası ve şifresiyle giriş yapın.
4. `Ana Akış`, `Etkinlikler`, `Profil`, `Ayarlar`, `Sosyal/Kullanıcı Ara` ve
   `Geri Bildirim` ekranlarını kontrol edin.

Ana akışlar:

- Etkinlikleri görüntüleme.
- Etkinlik detayını açma.
- Katılma isteği gönderme.
- Etkinlik oluşturma.
- Gönderi/akış ekranını görüntüleme.
- Profil ve kullanıcı arama ekranlarını görüntüleme.
- Geri bildirim veya şikayet araçlarını kontrol etme.

İşletme/organizasyon modu yalnızca test hesabı bu role hazırlanmışsa
incelenmelidir.

Hesap silme yolu:

- `Ayarlar` -> `Hesabımı sil`
- Bu akış bir hesap silme/deaktivasyon talebi oluşturur.

## English

Match A Man is a sports and social activity event app. It is not a dating app.

Login is required to access the main app features.

Test account:

- Email: `REVIEWER_TEST_EMAIL_PLACEHOLDER`
- Password: `REVIEWER_TEST_PASSWORD_PLACEHOLDER`

Login steps:

1. Open the app.
2. Go to `Giriş Yap`.
3. Enter the test email and password.
4. Review `Ana Akış`, `Etkinlikler`, `Profil`, `Ayarlar`,
   `Sosyal/Kullanıcı Ara`, and `Geri Bildirim`.

Main flows:

- View events.
- Open event details.
- Send a join request.
- Create an event.
- View feed/posts.
- View profile and user search.
- Check feedback/reporting/community safety tools.

Business/organization mode should be reviewed only if the reviewer test account
is prepared for that role.

Account deletion path:

- `Ayarlar` -> `Hesabımı sil`
- This creates an account deletion/deactivation request.

## Email Auth Note

- Email/password reviewer accounts should be pre-confirmed in Supabase Auth, or
  the reviewer must be able to open the confirmation email link.
- On first login, the reviewer only needs to choose a username if prompted.
  Full profile completion is not required before reviewing the app.
- Password reset uses a Supabase email link. Do not share real reset links or
  real passwords in this document.
