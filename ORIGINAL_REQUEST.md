# Original User Request

## Initial Request — 2026-06-13T19:03:11+03:00

Match A Man (MAM) — Mevcut canlı Flutter sosyal spor/etkinlik mobil uygulamasına 9 büyük özellik eklenmesi ve modernizasyonu. Uygulama Riverpod state management, GoRouter navigation, Supabase backend kullanıyor. Tüm değişiklikler Android ve iOS cross-platform uyumlu olmalı. Bu bir production uygulamasıdır — gerçek kullanıcılar tarafından kullanılmaktadır.

Working directory: c:\Users\Emirhan\Desktop\Match_A_Man\mam
Integrity mode: demo

## Existing Architecture Context

**Tech Stack**: Flutter (SDK ^3.11.4), flutter_riverpod ^2.6.1, go_router ^14.8.1, supabase_flutter ^2.9.1, Firebase (FCM), google_fonts, image_picker, geocoding, geolocator

**State Management Pattern (MUST FOLLOW)**: Every feature follows this exact pattern:
1. **Models** — Immutable data classes with `fromJson()`, `copyWith()`, computed getters
2. **Service** — `const` class wrapping Supabase client calls (queries, RPCs, storage)
3. **Provider** — Riverpod `StateNotifierProvider` with explicit state classes (status enum + data + message + loading flags)
4. **Controller** — `StateNotifier<XState>` with async methods, error handling via `friendlyErrorMessage()`

**Theme**: Material 3, Plus Jakarta Sans font, Primary: Coral #FF7E79, Secondary: Sky Blue #7CB9E8, Tertiary: Gold #FFD966, Background: Warm White #FDFBF9

**Feature Directories**: `lib/features/` contains: auth, business, chat, events, feed, feedback, follow, home, notifications, profile, reports, settings, social, trust_score, user_search

**Navigation**: 5-tab bottom nav → Home, Events, Create, Social, Profile

**Database (Supabase)**: Tables include: profiles, events, event_participants, event_join_requests, event_messages, posts, post_likes, post_comments, follows, follow_requests, notifications, business_accounts, business_applications, business_members, business_reviews, trust_score_logs, rate_limit_events, badges, user_badges, reports, blocks, user_feedback, account_deletion_requests, user_push_tokens, push_notification_outbox, admin_users

**Existing DB columns of note**:
- `profiles`: user_id, username, tag, account_type ('user'/'business'), business_account_id, is_private, trust_score (default 50), avatar_url, city, district, bio
- `events`: host_id, sport_type, organizer_type ('user'/'business'), organizer_business_id, is_sponsored, sponsored_until, sponsored_priority
- `business_accounts`: owner_user_id, name, username, business_tag, category, is_verified, status, logo_url, cover_url
- `rate_limit_events`: user_id, action, target_id, created_at
- `notifications`: recipient_id, actor_id, type, title, body, entity_type, entity_id, metadata, is_read

**Existing RPC Functions**: check_and_record_rate_limit, follow_or_request_user, approve_follow_request, reject_follow_request, request_event_join, get_visible_feed_posts_with_stats, switch_profile_account_type, and ~50 more

**CRITICAL RULES**:
- Any Supabase SQL mutations (CREATE TABLE, ALTER TABLE, INSERT, CREATE POLICY, CREATE FUNCTION) MUST be prepared as migration files, NOT executed directly. Place them in `supabase/migrations/` directory as timestamped SQL files (e.g., `20260613_add_business_plus.sql`). The user will review and apply them manually.
- Preserve ALL existing Riverpod provider patterns. Do not switch to different state management.
- App language is Turkish (tr_TR). All user-facing strings must be in Turkish.
- All UI changes must work on both Android and iOS. Use `Platform.isIOS` checks where needed and prefer Cupertino-style adaptations for iOS (e.g., `CupertinoAlertDialog`, smooth scrolling, safe area insets).

## Requirements

### R1. İşletme Hesabı Gizlilik Kısıtlaması
İşletme hesapları (`account_type = 'business'`) asla gizli hesap (`is_private = true`) olamaz. Bu kural hem veritabanı seviyesinde (trigger/constraint) hem de uygulama katmanında (profil ayarları UI'da gizlilik toggle'ı devre dışı bırakılmalı) zorlanmalı. Mevcut `switch_profile_account_type` RPC fonksiyonu ve `settings_page.dart` bu kurala uygun güncellenmeli.

### R2. Fotoğraf Kırpma Aracı
Fotoğraf paylaşımında (post oluşturma ve avatar yükleme) `image_picker` ile seçilen görseller, paylaşmadan önce bir kırpma ekranından geçmeli. Kırpma aracı Instagram/VSCO tarzı basit bir deneyim sunmalı: 1:1 (kare), 4:5 (portre), 16:9 (yatay) en-boy oranı seçimi ve serbest kırpma modu. Paylaşılan fotoğraflar artık orantısız görünmemeli — kırpılan oran korunarak gösterilmeli. Uygun bir Flutter kırpma paketi (örneğin `image_cropper`) kullanılabilir.

### R3. Etkinlikler Sayfası Sekme Yapısı
Mevcut etkinlikler sayfası (`events_page.dart`) iki sekmeye ayrılmalı:
- **Öne Çıkanlar**: Algoritmik sıralama — güven skoru yüksek kullanıcıların etkinlikleri, katılımcı sayısı yüksek olanlar, sponsorlu etkinlikler, İşletme Plus paketli işletmelerin etkinlikleri. İşletme profil önerileri de bu sekmede algoritmik olarak gösterilmeli.
- **Takip Edilenler**: Sadece kullanıcının takip ettiği kişilerin oluşturduğu/katıldığı etkinlikler. İşletme profil önerileri burada da gösterilmeli.

### R4. Ana Sayfa Karışık Feed
Ana sayfa (`home_page.dart`) akışı şu kaynaklardan karışık bir feed oluşturmalı:
1. **Takip edilen** kullanıcıların paylaştığı fotoğraflar ve oluşturduğu etkinlikler
2. **Keşfet** — yeni ve önerilen kullanıcıların etkinlikleri (henüz takip edilmeyen)
3. **Geçmiş katılımcılar (profil kartı)** — geçmiş etkinliklerde bir araya gelinen kişiler, profil kartı (kişi öneri kartı) olarak feed'de gösterilmeli
4. **Geçmiş katılımcıların fotoğrafları** — geçmiş etkinliklerde bir araya gelinen kişilerin paylaştığı fotoğraflar, sanki takip ediliyormuş gibi home feed'e düşmeli
Bu dört kaynak karışık olarak feed'e düşmeli. Feed'de post kartları, etkinlik kartları ve profil öneri kartları bir arada gösterilmeli.

### R5. Bildirim Sayfası Yeniden Tasarımı
Bildirim sayfası (`notifications_page.dart`) Instagram standardına oturtulmalı:
- Standart kutucuk boyutları (avatar 44px, padding/spacing tutarlı)
- Takip istekleri (`follow_request` tipindeki bildirimler) en üstte ayrı bir stack/grup olarak gösterilmeli (tıklandığında takip istekleri listesi açılmalı)
- Diğer bildirimler kronolojik sırada, "Bugün" / "Bu Hafta" / "Daha Önce" gibi zaman gruplarıyla ayrılmalı
- Her bildirim tipi için uygun ikon gösterilmeli

### R6. Günlük Etkinlik Paylaşım Limitleri
Mevcut `rate_limit_service.dart` ve `check_and_record_rate_limit` RPC fonksiyonunu genişleterek:
- **Yeni kullanıcılar** (trust_score < 60): Günde maksimum 2 etkinlik oluşturabilir
- **Güvenilir kullanıcılar** (trust_score ≥ 60): Günde maksimum 3 etkinlik oluşturabilir
- **İşletme hesapları**: Ayda standart 3 etkinlik oluşturabilir (İşletme Plus paketi hariç)
- Limit aşıldığında kullanıcıya anlaşılır bir Türkçe hata mesajı gösterilmeli

### R7. İşletme Plus Paketi
Yeni bir `business_plus_subscriptions` tablosu/yapısı oluşturulmalı (ödeme entegrasyonu şu an yapılmayacak, sadece altyapı ve UI):
- **Haklar**: Ayda 30 etkinlik (standart 3 yerine), ayda 5 öne çıkarma hakkı, işletme profilinin üst sıralarda görünmesi, etkinlik istatistikleri, katılımcı/talep yönetimi dashboard'u, sponsorlu işletme rozeti, öncelikli destek badge'i
- **İşletme profil özelleştirme** (Plus ve standart): Tema rengi seçimi, özel galeri bölümü, öne çıkan etkinlik pinleme
- `business_accounts` tablosuna gerekli yeni sütunlar eklenmeli
- İşletme profil sayfasında Plus avantajları ve abonelik durumu gösterilmeli
- Sponsorlu işletme rozeti UI'da görünür olmalı

### R8. Eski Sayfa Tasarım Modernizasyonu
Uygulamadaki tasarım bütünlüğünü bozan eski sayfalar tespit edilip modern UI standartlarına (mevcut tema: Coral primary, Plus Jakarta Sans, Material 3) uygun şekilde güncellenmeli. Riverpod mantığı ve mevcut provider yapısı BOZULMADAN, sadece build() metotları ve widget ağaçları düzenlenmeli. Özellikle tutarsız spacing, eski widget'lar (deprecated), tema dışı renkler ve responsive olmayan layout'lar düzeltilmeli.

### R9. iOS Uyumluluk
Tüm yeni ve mevcut sayfalar iOS'ta düzgün çalışmalı. SafeArea, CupertinoAlertDialog (iOS'ta), edge-to-edge layout, status bar rengi, bottom sheet davranışı gibi platform-specific detaylar doğru uygulanmalı. `Platform.isIOS` kontrolleri gereken yerlerde eklenmeli.

## Acceptance Criteria

### İşletme Gizlilik (R1)
- [ ] İşletme hesabı olan profiller is_private = false olarak zorlanıyor (DB trigger + UI kısıtlaması)
- [ ] Settings sayfasında işletme hesabı aktifken "Gizli Profil" toggle'ı disabled/hidden olarak görünüyor
- [ ] Kullanıcı tipi 'business'e geçtiğinde is_private otomatik false'a dönüyor

### Fotoğraf Kırpma (R2)
- [ ] Post oluşturma akışında image_picker sonrası kırpma ekranı açılıyor
- [ ] Avatar yükleme akışında da kırpma ekranı açılıyor
- [ ] 1:1, 4:5, 16:9 ve serbest kırpma oranları seçilebiliyor
- [ ] Kırpılan fotoğraf feed'de doğru oranlarla (orantısız uzama/sıkışma olmadan) görüntüleniyor

### Etkinlikler Sekmesi (R3)
- [ ] Etkinlikler sayfasında "Öne Çıkanlar" ve "Takip Edilenler" olmak üzere 2 sekme var
- [ ] Öne Çıkanlar sekmesi algoritmik sıralama uyguluyor (trust score, katılımcı, sponsored, Plus)
- [ ] Takip Edilenler sekmesi sadece takip edilen kullanıcıların etkinliklerini gösteriyor
- [ ] Her iki sekmede işletme profil önerileri algoritmik olarak gösterilir

### Ana Sayfa Feed (R4)
- [ ] Home sayfası dört kaynaktan karışık feed gösteriyor (takip, keşfet, geçmiş katılımcı profilleri, geçmiş katılımcı fotoğrafları)
- [ ] Feed'de post kartları, etkinlik kartları ve profil öneri kartları karışık gösteriliyor
- [ ] Geçmiş etkinliklerde bir araya gelinen kişiler profil kartı olarak feed'de öneriliyor
- [ ] Geçmiş katılımcıların paylaştığı fotoğraflar, takip edilmese bile home feed'de görünüyor

### Bildirim Sayfası (R5)
- [ ] Takip istekleri en üstte ayrı bir stack olarak gruplanıyor
- [ ] Diğer bildirimler zaman gruplarıyla (Bugün/Bu Hafta/Daha Önce) ayrılıyor
- [ ] Bildirim kutucukları standart boyutlarda (44px avatar, tutarlı padding)
- [ ] Her bildirim tipi için uygun ikon gösteriliyor

### Etkinlik Limitleri (R6)
- [ ] Yeni kullanıcılar (trust<60) günde 2, güvenilirler (trust≥60) günde 3 etkinlik oluşturabiliyor
- [ ] İşletmeler ayda 3 etkinlik oluşturabiliyor (Plus hariç)
- [ ] Limit aşılınca Türkçe hata mesajı gösteriliyor
- [ ] Rate limit kontrolü hem client hem server tarafında çalışıyor

### İşletme Plus (R7)
- [ ] business_plus_subscriptions tablosu (veya eşdeğer) migration dosyası hazır
- [ ] Plus paketli işletmeler ayda 30 etkinlik, 5 öne çıkarma hakkına sahip
- [ ] İşletme profil sayfasında Plus avantajları ve sponsorlu rozet görünüyor
- [ ] İşletme profil özelleştirme: tema rengi, galeri, etkinlik pinleme mevcut
- [ ] Migration dosyaları `supabase/migrations/` altında hazır (execute edilmemiş)

### UI Modernizasyonu (R8)
- [ ] Tema dışı renkler, tutarsız spacing, deprecated widget'lar düzeltildi
- [ ] Tüm sayfalar mevcut tema (Coral, Plus Jakarta Sans, Material 3) ile uyumlu
- [ ] Mevcut Riverpod provider/controller mantığı değiştirilmedi

### iOS Uyumluluk (R9)
- [ ] SafeArea tüm sayfalarda doğru uygulanıyor
- [ ] iOS'ta CupertinoAlertDialog kullanılıyor
- [ ] Status bar, bottom sheet, keyboard davranışı iOS'ta doğru çalışıyor

## Verification Plan

### Automated Tests
- `flutter analyze` — Tüm static analysis hataları temizlenmeli
- `flutter build apk --debug` — Android build başarılı olmalı
- `flutter build ios --no-codesign` — iOS build başarılı olmalı (code signing olmadan)

### Manual Verification
- Migration SQL dosyaları syntax-valid olmalı (psql veya Supabase SQL editor'da parse edilebilir)
- Tüm yeni dosyalar mevcut pattern'e uygun organize edilmeli (models → service → provider → page)
- Yeni/değiştirilen her sayfanın mevcut tema renklerini kullandığını görsel olarak doğrulayın
