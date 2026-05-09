# Match A Man — Product Requirements Document

**Sürüm:** v0.1  
**Ürün:** Match A Man  
**Platform:** Mobil uygulama — Flutter / Android / iOS  
**Doküman tipi:** Product Requirements Document, PRD  
**Durum:** Launch V1 / MVP+ kapsam dokümanı  

---

## 1. Ürün Özeti

**Match A Man**, kullanıcıların yakınlarındaki spor ve sosyal etkinlikleri keşfedebildiği, etkinlik oluşturabildiği, katılım isteği gönderebildiği, onaylandıktan sonra grup sohbetine katılabildiği ve etkinlik sonrası fotoğraf paylaşarak sosyal profillerini güçlendirebildiği mobil bir sosyal etkinlik uygulamasıdır.

Uygulama klasik bir dating app değildir. Ancak insanların spor ve etkinlik üzerinden doğal biçimde tanışmasını, sosyalleşmesini ve sosyal çevre oluşturmasını sağlar.

Ana his:

- Sosyal
- Enerjik
- Sportif
- Güven veren
- Ucuz dating app havasından uzak

---

## 2. Ürün Vizyonu

Match A Man’in uzun vadeli vizyonu:

> İnsanların spor ve sosyal etkinlikler üzerinden güvenli, canlı ve gerçek dünyaya bağlı bir sosyal çevre oluşturmasını sağlayan büyük ölçekli bir platform olmak.

Kullanıcı uygulamaya girdiğinde şu hissi almalı:

> “Burada yakınımda gerçek insanlar gerçek etkinlikler yapıyor. Ben de katılabilirim, sosyalleşebilirim ve profilimi zamanla güçlendirebilirim.”

Bu ürünün merkezi **etkinliktir**. Sosyal feed, fotoğraf, like, yorum, takip ve profil sistemi etkinlik omurgasını destekler.

---

## 3. Problem

İnsanların özellikle şehir hayatında şu problemleri var:

1. Spor veya sosyal etkinlik yapmak istiyorlar ama ekip bulamıyorlar.
2. Halı saha, voleybol, tenis, koşu, doğa yürüyüşü gibi aktivitelerde eksik kişi bulmak zor oluyor.
3. Yeni insanlarla tanışmak istiyorlar ama doğrudan dating app kullanmak istemiyorlar.
4. Mevcut sosyal medya platformları etkinlik katılımı için tasarlanmamış.
5. WhatsApp grupları dağınık, kapalı ve keşfedilebilir değil.
6. Etkinliğe katılacak kişilere güvenmek zor.
7. İnsanların sosyal profili gerçek hayattaki aktivitelerle güçlenmiyor.
8. İşletmelerin veya etkinlik sahiplerinin doğru kitleye etkinlik duyurması zor.

---

## 4. Çözüm

Match A Man şu çözümü sunar:

Kullanıcılar:

- Yakınlarındaki etkinlikleri görür.
- Etkinlik oluşturur.
- Başkalarının etkinliklerine katılmak için istek gönderir.
- Host, katılım isteğini onaylar veya reddeder.
- Onaylanan kişi etkinlik kontenjanına dahil olur.
- Onaylanan kullanıcı etkinlik içi grup sohbetine katılır.
- Onay sonrası host veya katılımcı, izinli durumlarda arama butonunu kullanabilir.
- Etkinlik sonrası isteğe bağlı fotoğraf paylaşır.
- Fotoğraflara like ve yorum alır.
- Diğer kullanıcıları takip eder.
- Profilinde geçmiş etkinliklerini ve paylaşımlarını gösterir.
- Güvenilirlik davranışları trust score’a yansır.

---

## 5. Ana Ürün Döngüsü

Match A Man’in temel ürün döngüsü:

```txt
Etkinlik gör
→ Katılmak iste
→ Host onaylasın
→ Etkinlik içi sohbete gir
→ Etkinliğe git
→ Fotoğraf paylaş
→ Like / yorum al
→ Profil güçlensin
→ Tekrar etkinliğe katıl veya etkinlik oluştur
```

Bu döngü ürünün kalbidir.

Eğer bu döngü çalışmazsa uygulama sadece “etkinlik ilan panosu” olur. Eğer bu döngü çalışırsa uygulama sosyal ağa dönüşebilir.

---

## 6. Hedef Kullanıcılar

### 6.1. Birincil Kullanıcılar

**Spor yapmak isteyen ama ekip bulmakta zorlanan kişiler**

Örnek:

- Halı sahada eksik oyuncu arayanlar
- Voleybol grubu kurmak isteyenler
- Koşu arkadaşı arayanlar
- Tenis partneri arayanlar
- Doğa yürüyüşü grubu bulmak isteyenler
- Basketbol, padel, fitness, bisiklet gibi aktivitelerde partner veya grup arayanlar

### 6.2. Sosyalleşmek İsteyen Kullanıcılar

Bu kullanıcıların motivasyonu yalnızca spor değildir.

İstedikleri şey:

- Yeni insanlarla tanışmak
- Sosyal çevre oluşturmak
- Gerçek etkinliklere katılmak
- Fotoğraf ve profil üzerinden sosyal kanıt oluşturmak
- Dating app kullanmadan sosyal görünürlük kazanmak

### 6.3. Host Kullanıcılar

Etkinlik oluşturan kişiler.

İhtiyaçları:

- Eksik kişileri bulmak
- Katılım isteklerini kontrol etmek
- Katılımcılarla iletişim kurmak
- Güvenilir kişileri seçmek
- Etkinlik sonrası sosyal görünürlük kazanmak

### 6.4. Gelecekteki İşletme Kullanıcıları

MVP’de işletme paneli yok. Ancak ileride şu işletmeler platforma sponsorlu etkinlik verebilir:

- At çiftlikleri
- Spor salonları
- Halı sahalar
- Organizasyon firmaları
- Workshop/aktivite mekanları
- Tenis kortları
- Outdoor aktivite şirketleri

MVP’de bu sadece manuel “Sponsorlu” etiketiyle temsil edilecek.

---

## 7. Platform

Başlangıç platformu:

```txt
Mobil uygulama
Flutter
Android + iOS
```

Web panel, işletme paneli, gelişmiş admin panel Launch V1 kapsamında yoktur.

---

## 8. Teknoloji Kararları

Kullanılacak temel teknolojiler:

```txt
Flutter
Riverpod
Supabase
go_router
Supabase Auth
Supabase Storage
Firebase sadece gerekirse push notification için
```

Auth:

```txt
Email login
Google login
Apple login
Facebook login yok
```

Storage:

```txt
Başlangıçta Supabase Storage
```

Push notification:

```txt
Gerekirse Firebase Cloud Messaging
```

---

## 9. Mimari Karar

Uygulama **Shallow Feature-First Architecture** ile geliştirilecek.

Temel akış:

```txt
Page → Provider → Service → Supabase/Firebase
```

Kurallar:

- Page sadece UI render eder.
- Page provider metodlarını çağırır.
- Page içinde Supabase/Firebase çağrısı olmaz.
- Provider state yönetir.
- Provider loading/error/success durumlarını tutar.
- Provider raw Supabase query yazmaz.
- Service Supabase/Firebase ile konuşur.
- Service içinde UI kodu olmaz.
- Model dosyaları ilgili feature içinde kalır.
- Ağır Clean Architecture kullanılmaz.
- Gereksiz abstract class açılmaz.
- Repository/usecase/datasource/mapper katmanları kullanılmaz.
- Dosyalar devleşirse widget veya yardımcı parçalara bölünür.
- Ortak widget’lar `core/widgets` içinde kalır.
- Feature-specific widget’lar kendi feature klasöründe kalır.

Bu mimari kararın amacı:

```txt
Hızlı geliştirme
AI/Codex ile daha az bağlam kaybı
Spagettiyi önleme
Aşırı Clean Architecture karmaşasından kaçınma
```

---

## 10. Dosya Yapısı Hedefi

Başlangıç hedef dosya yapısı:

```txt
lib/
├── main.dart
├── bootstrap.dart
├── app.dart
│
├── core/
│   ├── config/
│   │   └── env.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   └── route_names.dart
│   ├── theme/
│   │   ├── app_theme.dart
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   ├── app_spacing.dart
│   │   └── app_radius.dart
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── app_loader.dart
│   │   ├── empty_state.dart
│   │   └── error_view.dart
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── date_formatter.dart
│   │   └── image_utils.dart
│   └── errors/
│       ├── app_exception.dart
│       └── failure.dart
│
├── services/
│   ├── supabase_service.dart
│   ├── storage_service.dart
│   └── notification_service.dart
│
└── features/
    ├── auth/
    ├── profile/
    ├── events/
    ├── feed/
    ├── follow/
    ├── chat/
    ├── notifications/
    ├── trust_score/
    ├── reports/
    └── settings/
```

Örnek events feature yapısı:

```txt
features/events/
├── events_page.dart
├── event_detail_page.dart
├── create_event_page.dart
├── events_provider.dart
├── events_service.dart
├── events_models.dart
└── widgets/
    ├── event_card.dart
    ├── sport_chip.dart
    └── join_event_button.dart
```

Örnek feed feature yapısı:

```txt
features/feed/
├── feed_page.dart
├── create_post_page.dart
├── feed_provider.dart
├── feed_service.dart
├── feed_models.dart
└── widgets/
    ├── post_card.dart
    ├── post_actions.dart
    └── comment_sheet.dart
```

---

## 11. MVP+ Kapsamı

Bu ürün çıplak MVP değildir. Daha doğru isim:

```txt
Launch V1 / MVP+
```

### 11.1. MVP+ İçinde Olacaklar

#### Auth

- Email login
- Google login
- Apple login
- Facebook login
- Supabase Auth

#### Profil

- Username + tag  
  Örnek: `Emirhan#4355`
- Profil fotoğrafı
- Profil tamamlama
- İsim
- Soyisim
- Doğum tarihi
- Cinsiyet
- Şehir

#### Etkinlik

- Etkinlik oluşturma
- Etkinlik listeleme
- Etkinlik detay sayfası
- Konum / şehir / ilçe filtresi
- Branş filtresi
- Katılım isteği
- Host onay / red
- Kontenjan güncelleme
- Kadın / erkek / fark etmez kontenjanı
- Basit sponsorlu etkinlik etiketi

#### İletişim

- Etkinlik içi grup sohbeti
- Birebir mesajlaşma yok
- Onay sonrası arama butonu
- Telefon numarası herkese açık gösterilmez

#### Sosyal

- Fotoğraf paylaşımı
- Like
- Yorum
- Basit ana sayfa feed
- Basit takip sistemi
- Profilde geçmiş etkinlikler
- Profilde paylaşımlar
- Çok basit story/moment hissi

#### Güvenlik

- Basit trust score
- Gelmeme / son dakika iptal davranışlarının trust score’a yansıması
- Raporlama
- Engelleme
- Basit/manual admin moderasyon

---

## 12. MVP+ Dışında Kalacaklar

Launch V1 içinde olmayacaklar:

```txt
Birebir mesajlaşma
Harita görünümü
Uygulama içi ödeme
Komisyon sistemi
İşletme paneli
Abonelik
Premium grup
Gelişmiş admin panel
Gelişmiş analytics
Gelişmiş algoritmik feed
Tam Instagram story sistemi
```

Bu özellikler ürün yol haritasında ileride değerlendirilebilir ama Launch V1 kapsamına dahil değildir.

---

## 13. Ana Özellik Gereksinimleri

## 13.1. Auth

### Amaç

Kullanıcıların güvenli biçimde hesap oluşturması ve giriş yapması.

### Gereksinimler

- Kullanıcı email/password ile kayıt olabilir.
- Kullanıcı email/password ile giriş yapabilir.
- Kullanıcı çıkış yapabilir.
- Google login desteklenir.
- Apple login desteklenir.
- Facebook login desteklenir.
- Auth Supabase üzerinden yönetilir.

### Başarı Kriteri

Kullanıcı hesap oluşturup uygulamaya girebilir.

---

## 13.2. Profil Tamamlama

### Amaç

Etkinlik oluşturma ve katılım süreçleri için kullanıcı kimliğini temel seviyede güvenilir hale getirmek.

### Zorunlu Bilgiler

```txt
İsim
Soyisim
Doğum tarihi
Cinsiyet
Şehir
Username + tag
```

### Kural

Profil tamamlanmadan kullanıcı etkinlik oluşturamamalı.

### Başarı Kriteri

Kullanıcı profilini tamamladıktan sonra etkinlik oluşturma ve katılım akışlarına erişebilir.

---

## 13.3. Etkinlik Listeleme

### Amaç

Kullanıcıların yakınlarındaki veya ilgilendikleri spor/sosyal etkinlikleri keşfetmesini sağlamak.

### Gereksinimler

- Etkinlik kartları listelenir.
- Kullanıcı şehir/ilçe filtresi yapabilir.
- Kullanıcı branş filtresi yapabilir.
- Sponsorlu etkinlikler “Sponsorlu” etiketiyle gösterilir.

### Etkinlik Kartında Gösterilecek Bilgiler

```txt
Başlık
Branş
Tarih/saat
Şehir/ilçe
Kontenjan bilgisi
Host bilgisi
Sponsorlu etiketi varsa görünür
```

---

## 13.4. Etkinlik Oluşturma

### Amaç

Host kullanıcıların spor veya sosyal etkinlik oluşturmasını sağlamak.

### Gereksinimler

Host şu bilgileri girebilir:

```txt
Etkinlik başlığı
Açıklama
Branş
Şehir
İlçe
Konum metni
Harita üzerinden tam konum
Tarih/saat
Toplam kontenjan
Kadın kontenjanı
Erkek kontenjanı
Fark etmez kontenjanı
```

### Kural

Profil tamamlanmadan etkinlik oluşturulamaz.

---

## 13.5. Katılım İsteği

### Amaç

Etkinliğe katılımı kontrollü hale getirmek.

### Gereksinimler

- Kullanıcı etkinliğe katılım isteği gönderebilir.
- Aynı kullanıcı aynı etkinliğe tekrar istek gönderemez.
- Host isteği onaylayabilir veya reddedebilir.
- Onaylanan kullanıcı kontenjana dahil olur.
- Reddedilen kullanıcı etkinliğe dahil olmaz.
- Kontenjan dolduysa yeni istek yapılamaz.

### Başarı Kriteri

Kullanıcı host onayı olmadan etkinlik katılımcısı sayılmaz.

---

## 13.6. Etkinlik İçi Grup Sohbeti

### Amaç

Onaylanan katılımcıların etkinlik öncesi iletişim kurmasını sağlamak.

### Gereksinimler

- Sadece onaylı katılımcılar sohbete girebilir.
- Host sohbeti görebilir.
- Mesajlar text tabanlıdır.
- Medya mesajı MVP’de yoktur.
- Birebir mesajlaşma yoktur.

---

## 13.7. Onay Sonrası Arama Butonu

### Amaç

Birebir mesajlaşma olmadan, etkinlik iletişimini pratik hale getirmek.

### Gereksinimler

- Katılımcı sadece onaylandıysa host’u arayabilir.
- Host onaylı katılımcıları arayabilir.
- Telefon numarası herkese açık gösterilmez.
- Arama butonu yalnızca izinli ilişkide görünür.

---

## 13.8. Feed ve Fotoğraf Paylaşımı

### Amaç

Uygulamaya sosyal canlılık ve profil gücü kazandırmak.

### Gereksinimler

- Kullanıcı fotoğraf paylaşabilir.
- Paylaşım açıklama içerebilir.
- Paylaşım bir etkinlikle ilişkilendirilebilir.
- Kullanıcı paylaşımları ana feed’de görülebilir.
- Kullanıcıların profilinde paylaşımları görünebilir.
- Feed basit sıralama ile çalışır.
- Gelişmiş algoritmik feed yoktur.

---

## 13.9. Like ve Yorum

### Amaç

Sosyal etkileşimi artırmak.

### Gereksinimler

- Kullanıcı post like edebilir.
- Like geri alınabilir.
- Kullanıcı yorum yapabilir.
- Yorumlar post altında gösterilir.
- Yorum raporlanabilir olmalıdır.

---

## 13.10. Takip Sistemi

### Amaç

Kullanıcıların sosyal bağ kurmasını sağlamak.

### Gereksinimler

- Kullanıcı başka kullanıcıyı takip edebilir.
- Takibi bırakabilir.
- Profilde takipçi ve takip edilen sayısı gösterilir.
- Gelişmiş takip algoritması yoktur.

---

## 13.11. Story / Moment Hissi

### Amaç

Uygulamaya güncel ve canlı sosyal atmosfer katmak.

### Gereksinimler

- Tam Instagram story sistemi yapılmaz.
- Basit etkinlik/anı paylaşımı hissi verilir.
- 24 saatlik kompleks story altyapısı zorunlu değildir.
- UI sosyal ve canlı hissettirmelidir.

---

## 13.12. Trust Score

### Amaç

Kullanıcı güvenilirliğini basit ve anlaşılır şekilde göstermek.

### Gereksinimler

Trust score şunlardan etkilenebilir:

```txt
Etkinliğe katılım geçmişi
Onaylandıktan sonra gelmeme
Son dakika iptal
Raporlanma
Host davranışı
Katılımcı davranışı
```

MVP’de trust score basit tutulur.

Örnek gösterim:

```txt
Trust Score: 82
Güvenilir Katılımcı
Yeni Kullanıcı
Düşük Güven
```

---

## 13.13. Raporlama

### Amaç

Kötüye kullanım, taciz, spam, uygunsuz fotoğraf veya sahte etkinlik gibi durumları yönetmek.

### Raporlanabilir Varlıklar

```txt
Kullanıcı
Etkinlik
Post
Yorum
```

### Gereksinimler

- Kullanıcı rapor sebebi seçebilir.
- Açıklama yazabilir.
- Rapor admin/moderasyon tarafında görülebilir.
- MVP’de manuel Supabase panel moderasyonu yeterlidir.

---

## 13.14. Engelleme

### Amaç

Kullanıcı güvenliği ve kontrolü.

### Gereksinimler

- Kullanıcı başka kullanıcıyı engelleyebilir.
- Engellenen kullanıcıyla sosyal etkileşim sınırlandırılır.
- Engellenen kişinin içerikleri gizlenir.

---

## 13.15. Sponsorlu Etkinlik

### Amaç

İleride işletmelerin etkinliklerini görünür kılmak için basit bir temel oluşturmak.

### Gereksinimler

- MVP’de işletme paneli yoktur.
- Uygulama içi ödeme yoktur.
- Komisyon sistemi yoktur.
- Sponsorlu etkinlik yalnızca manuel olarak işaretlenebilir.
- Etkinlik kartında “Sponsorlu” etiketi gösterilir.

---

## 14. Temel Kullanıcı Akışları

### 14.1. Yeni Kullanıcı Akışı

```txt
Uygulamayı açar
→ Kayıt olur
→ Etkinliklere katılmak isterse önce profilini tamamlar
→ Etkinlikleri görür
→ Bir etkinliğe katılım isteği gönderir
→ Host onaylarsa grup sohbetine girer
→ Etkinliğe katılır
→ İsteğe bağlı fotoğraf paylaşır
```

### 14.2. Host Akışı

```txt
Giriş yapar
→ Profilini tamamlar
→ Etkinlik oluşturur
→ Katılım isteklerini görür
→ Kullanıcıları onaylar/reddeder
→ Onaylı kullanıcılarla sohbet eder
→ Gerekirse katılımcıyı arar
→ İsteğe bağlı fotoğraf paylaşır
```

### 14.3. Sosyal Akış

```txt
Feed’e girer
→ Fotoğrafları görür
→ Like atar
→ Yorum yapar
→ Kullanıcı profilini inceler
→ Takip eder
```

### 14.4. Güvenlik Akışı

```txt
Kullanıcı uygunsuz davranış görür
→ Kullanıcıyı/postu/etkinliği/yorumu raporlar
→ Gerekirse kullanıcıyı engeller
→ Rapor Supabase panelinden manuel incelenir
```

---

## 15. Veri Modeli — İlk Taslak

Başlangıç tabloları:

```txt
profiles
events
event_join_requests
event_participants
event_messages
posts
post_likes
post_comments
follows
reports
blocks
```

### 15.1. Profiles

```txt
id
user_id
username
tag
first_name
last_name
birth_date
gender
city
district
phone
avatar_url
trust_score
is_profile_completed
created_at
updated_at
```

### 15.2. Events

```txt
id
host_id
title
description
sport_type
city
district
location_text
event_date
capacity_total
capacity_male
capacity_female
capacity_any
approved_count
status
is_sponsored
created_at
updated_at
```

### 15.3. Event Join Requests

```txt
id
event_id
user_id
status
created_at
updated_at
```

### 15.4. Event Participants

```txt
id
event_id
user_id
role
joined_at
attendance_status
```

### 15.5. Event Messages

```txt
id
event_id
sender_id
message
created_at
```

### 15.6. Posts

```txt
id
user_id
event_id
image_url
caption
created_at
```

### 15.7. Post Likes

```txt
id
post_id
user_id
created_at
```

### 15.8. Post Comments

```txt
id
post_id
user_id
comment
created_at
```

### 15.9. Follows

```txt
id
follower_id
following_id
created_at
```

### 15.10. Reports

```txt
id
reporter_id
target_type
target_id
reason
description
status
created_at
```

### 15.11. Blocks

```txt
id
blocker_id
blocked_id
created_at
```

---

## 16. Navigasyon Yapısı — İlk Taslak

Ana sekmeler:

```txt
Etkinlikler
Feed
Oluştur
Social
Profil
```

Alternatif isimlendirme:

```txt
Home
Events
Create
Social
Profile
```

Tercih edilen ilk yapı:

```txt
Etkinlikler
Feed
Oluştur
Social
Profil
```

Çünkü ürünün omurgasını açıkça etkinlik yapıyor.

---

## 17. Bildirim Gereksinimleri

MVP’de bildirimler basit başlayabilir.

Bildirim tetikleyicileri:

```txt
Katılım isteği geldi
Katılım isteği onaylandı
Katılım isteği reddedildi
Etkinlik sohbetinde mesaj geldi
Post like aldı
Post yorum aldı
Yeni takipçi geldi
```

Push notification Firebase ile eklenecek.

---

## 18. Admin / Moderasyon

MVP’de gelişmiş admin panel yok.

Başlangıç moderasyon yöntemi:

```txt
Supabase panel üzerinden manuel kontrol
```

Admin/moderasyonun göreceği şeyler:

```txt
Raporlar
Kullanıcılar
Etkinlikler
Postlar
Yorumlar
Engelleme kayıtları
Trust score etkileyen davranışlar
```

---

## 19. Başarı Metrikleri

### 19.1. Aktivasyon

```txt
Kayıt olan kullanıcı sayısı
Profil tamamlama oranı
İlk etkinlik görüntüleme oranı
İlk katılım isteği gönderme oranı
```

### 19.2. Etkinlik

```txt
Oluşturulan etkinlik sayısı
Etkinlik başına katılım isteği sayısı
Onaylanan katılım oranı
Etkinlik doluluk oranı
```

### 19.3. Sosyal

```txt
Paylaşılan fotoğraf sayısı
Post başına like
Post başına yorum
Takip etme oranı
```

### 19.4. Güvenlik

```txt
Rapor sayısı
Engelleme sayısı
No-show oranı
Trust score dağılımı
```

### 19.5. Retention

```txt
D1 retention
D7 retention
Tekrar etkinliğe katılım oranı
Tekrar etkinlik oluşturma oranı
```

---

## 20. Kritik Riskler

### 20.1. Boş Uygulama Riski

Eğer kullanıcı uygulamaya girdiğinde etkinlik yoksa ürün ölü görünür.

Çözüm:

```txt
İlk lansmanı dar bölgede yapmak
Başlangıçta manuel/seed etkinlikler girmek
Üniversite, halı saha, spor çevresi gibi yoğun alanlara odaklanmak
```

### 20.2. Dating App Algısı

Fotoğraf, takip, like ve yorum sistemi yanlış tasarlanırsa uygulama dating app gibi algılanabilir.

Çözüm:

```txt
Etkinlik omurgası her zaman önde tutulmalı
Profil sosyal proof için kullanılmalı
UI ucuz flört uygulaması gibi görünmemeli
Fotoğraf paylaşımı etkinlik/anı bağlamıyla desteklenmeli
```

### 20.3. Güvenlik Riski

Yabancılarla etkinlik yapılacağı için güven kritik.

Çözüm:

```txt
Profil tamamlama
Trust score
Raporlama
Engelleme
Host onayı
Onay sonrası iletişim sınırı
```

### 20.4. Scope Şişmesi

Ürün aynı anda etkinlik, sosyal medya, chat ve güvenlik sistemi içeriyor.

Çözüm:

```txt
MVP+ kapsamı korunacak
Ama geliştirme sırası kontrollü olacak
Payment, işletme paneli, DM gibi dış kapsam özellikler eklenmeyecek
```

### 20.5. Codex / AI Bağlam Kaybı Riski

AI agent çok fazla dosyaya aynı anda dokunursa bozuk patch, duplicate kod veya context kaybı oluşabilir.

Çözüm:

```txt
Bağlantılı dosyalar birlikte verilecek
İlgisiz dosyalar aynı task'a konmayacak
Her değişiklikten sonra git diff / analyze / test kontrol edilecek
Temiz değişiklikler commitlenecek
```

---

## 21. Release Kriterleri

Launch V1’e çıkmadan önce şu kriterler sağlanmalı:

```txt
Kullanıcı kayıt olabilir
Kullanıcı giriş yapabilir
Kullanıcı profilini tamamlayabilir
Kullanıcı etkinlik oluşturabilir
Kullanıcı etkinlikleri listeleyebilir
Kullanıcı etkinliğe istek atabilir
Host isteği onaylayabilir/reddedebilir
Onaylanan kullanıcı grup sohbetine girebilir
Onaylanan kullanıcı/host arama butonunu kullanabilir
Kullanıcı fotoğraf paylaşabilir
Like ve yorum çalışır
Takip sistemi çalışır
Trust score temel seviyede çalışır
Raporlama çalışır
Engelleme çalışır
Sponsorlu etkinlik etiketi gösterilebilir
flutter analyze temiz
flutter test temiz
Temel manuel test senaryoları geçer
```

---

## 22. Etkinlik sohbet grupları

Event Chat Lifecycle

- Event chat is available only to the host and approved participants.
- The chat becomes active once the user is approved for the event.
- The chat remains active before and during the event.
- After the event time, the chat remains writable for 24 hours.
- After 24 hours, the chat becomes archived/read-only.
- Archived chats can be viewed from social(messasges) page messages.
- Archived chats cannot receive new messages.
- Messages are not automatically deleted because they may be needed for reporting, moderation, safety, or event history.

---

## 23. Geliştirme Fazları

### Faz 0 — Temel Proje İskeleti

```txt
Flutter setup
Riverpod
go_router
Supabase service
Theme
Core widgets
Folder structure
```

### Faz 1 — Auth

```txt
Email login
Email register
Logout
Auth state
Google login
Apple login
Facebook login
```

### Faz 2 — Profile

```txt
Username + tag
Profile completion
Required profile fields
```

### Faz 3 — Events

```txt
Event create
Event list
Event detail
Filters
Capacity
Sponsored label
```

### Faz 4 — Join Requests

```txt
Request to join
Host approve/reject
Participant creation
Capacity update
```

### Faz 5 — Event Chat + Call Button

```txt
Event group chat
Approved-only access
Host/participant call button
```

### Faz 6 — Feed

```txt
Photo post
Caption
Like
Comment
Simple feed
Profile posts
```

### Faz 7 — Follow

```txt
Follow
Unfollow
Follower/following count
```

### Faz 8 — Trust / Reports / Blocks

```txt
Trust score
Report user/post/event/comment
Block user
Manual moderation
```

### Faz 9 — Polish / Launch

```txt
UI polish
Error states
Loading states
Empty states
Manual testing
Build preparation
Launch checklist
```

---

## 23. Codex / AI Çalışma Kuralları

Kod geliştirme sürecinde AI agent kullanılacaksa şu kurallar geçerli olmalı:

- Her büyük değişiklikten önce `git status` kontrol edilir.
- Her anlamlı adımdan sonra commit atılır.
- `flutter analyze` temiz olmadan commit atılmaz.
- `flutter test` geçmeden commit atılmaz.
- Codex’e tehlikeli komutlarda kalıcı izin verilmez.
- `flutter pub get`, `flutter analyze`, `flutter test` gibi güvenli komutlar kontrollü çalıştırılır.
- “Tüm projeyi oku ve düzenle” tarzı görev verilmez.
- Sadece ilgili feature ve ilgili dosyalar verilir.
- Bozuk merge, duplicate content veya karışık patch görülürse hemen durdurulur.

Codex görevleri bağlantılı dosya paketleri halinde verilebilir. Ancak router, service, provider, UI ve test aynı anda çok geniş kapsamla verilmemelidir.

---

## 24. Tasarım İlkeleri

Figma’da tasarım sistemi çıkarıldıktan sonra uygulama genelinde aynı his korunmalıdır.

Tasarım kuralları:

- `AppColors` dışında renk uydurulmaz.
- `AppTextStyles` dışında rastgele font style verilmez.
- `AppSpacing` dışında rastgele margin/padding verilmez.
- `AppRadius` dışında rastgele radius verilmez.
- Ana butonlar `AppButton` ile yapılır.
- Ana inputlar `AppTextField` ile yapılır.
- Feature-specific widget’lar kendi feature klasöründe olur.
- Ortak widget’lar `core/widgets` içinde olur.
- UI enerjik, sportif, sosyal ve güven veren hissettirmelidir.
- Dating app gibi ucuz görünmemelidir.
- Fotoğraf, like ve sosyal proof önemlidir ama etkinlik omurgasını ezmemelidir.

Figma’dan koda geçiş sırası:

```txt
1. Design tokens çıkar
2. Theme dosyalarını kur
3. Core widgetları kur
4. Auth ekranları
5. Events ekranları
6. Event detail
7. Create event
8. Feed
9. Profile
10. Chat / notifications
```

---

## 25. Ürün İlkesi

Match A Man için temel ürün ilkesi:

> Her sosyal özellik, etkinlik omurgasını güçlendirmeli. Eğer bir özellik kullanıcıyı gerçek etkinliğe, güvene veya sosyal profile yaklaştırmıyorsa V1’de gereksizdir.

Bu şu anlama gelir:

- Fotoğraf paylaşımı var çünkü etkinlik sonrası sosyal proof sağlar.
- Like/yorum var çünkü sosyal canlılık sağlar.
- Takip var çünkü kullanıcılar arasında bağ kurar.
- Chat var çünkü etkinlik koordinasyonu sağlar.
- Trust score var çünkü güven sağlar.
- DM yok çünkü ürünü dating app’e kaydırabilir.
- Payment yok çünkü erken monetization ürünü yavaşlatır.

---

## 26. Kısa Sonuç

**Match A Man Launch V1**, bir etkinlik uygulamasından fazlası, ama dating app’ten farklı bir yerde duruyor.

En doğru tanım:

> Spor ve sosyal etkinlikler üzerinden insanların güvenli biçimde tanışmasını, katılmasını, paylaşmasını ve sosyal profil oluşturmasını sağlayan mobil topluluk platformu.

Bu PRD’nin en kritik cümlesi:

> Ürünün ana omurgası etkinliktir; sosyal özellikler etkinlik döngüsünü canlı tutmak için vardır.