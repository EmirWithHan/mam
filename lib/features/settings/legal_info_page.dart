import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_logo.dart';

enum LegalInfoType {
  privacyPolicy,
  termsOfUse,
  communityGuidelines,
  eventSafetyDisclaimer,
  support,
}

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({super.key, required this.type});

  final LegalInfoType type;

  @override
  Widget build(BuildContext context) {
    final content = _content(type);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Geri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/settings');
          },
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text(content.title, style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(content.notice, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.lgBorder,
              ),
              child: Padding(
                padding: AppResponsive.cardPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in content.sections) ...[
                      Text(section.title, style: AppTextStyles.title),
                      const SizedBox(height: AppSpacing.xs),
                      Text(section.body, style: AppTextStyles.body),
                      if (section != content.sections.last)
                        const SizedBox(height: AppSpacing.lg),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

_LegalContent _content(LegalInfoType type) {
  return switch (type) {
    LegalInfoType.privacyPolicy => const _LegalContent(
      title: 'Match A Man Gizlilik Politikası ve KVKK Aydınlatma Metni',
      notice:
          'Sürüm: privacy_v1_2026_06_10\nSon güncelleme: 10 Haziran 2026\nBu metin kapalı test MVP sürümü için hazırlanmış gizlilik ve aydınlatma bilgilendirmesidir.',
      sections: [
        _LegalSection(
          title: 'Veri sorumlusu ve iletişim',
          body:
              'Match A Man uygulamasında işlenen kişisel veriler için resmi iletişim ve destek kanalları uygulama içinde veya Match A Man’in resmi sayfalarında paylaşılır. Destek, veri talebi ve hesap silme başvuruları uygulama içindeki destek ve hesap kanalları üzerinden iletilebilir.',
        ),
        _LegalSection(
          title: 'Uygulamanın amacı',
          body:
              'Match A Man; kullanıcıların sosyal spor ve etkinlikler etrafında profil oluşturmasına, etkinlik keşfetmesine, etkinlik oluşturmasına, katılım isteği göndermesine, onaylı etkinlik sohbetlerine katılmasına, sosyal içerik paylaşmasına ve topluluk güvenliğini yönetmesine yardımcı olan bir platformdur.',
        ),
        _LegalSection(
          title: 'İşlenen kişisel veri kategorileri',
          body:
              'Kapalı test MVP sürümünde hesap kimliği, e-posta, giriş yöntemi, kullanıcı adı, etiket, ad, doğum tarihi, cinsiyet tercihi, şehir/ilçe, telefon numarası, profil açıklaması, avatar/profil fotoğrafı URL bilgisi, gizli hesap tercihi, güven puanı, hesap durumu, etkinlik katılımı, bildirimler, raporlar, engellemeler, geri bildirimler ve işletme başvuru bilgileri gibi uygulamanın çalışması için gerekli veriler işlenebilir.',
        ),
        _LegalSection(
          title: 'Hesap ve kimlik verileri',
          body:
              'E-posta/şifre ve Google ile giriş Supabase Auth üzerinden yürütülür. Google girişinde sağlayıcı tarafından dönen temel hesap bilgileri, oturum açma ve gerekiyorsa profil başlangıcı için kullanılabilir. E-posta, auth metadata, sağlayıcı tokenları ve benzeri hesap güvenliği alanları herkese açık profil alanlarında gösterilmez.',
        ),
        _LegalSection(
          title: 'Profil verileri',
          body:
              'Profilde kullanıcı adı, etiket, ad, şehir/ilçe, doğum tarihi, cinsiyet tercihi, telefon, bio, avatar, gizli hesap tercihi, takipçi/takip edilen ilişkileri, güven puanı ve profil tamamlama bilgileri yer alabilir. Profil görünürlüğü uygulamadaki gizlilik ayarlarına, takip ilişkilerine ve güvenlik kurallarına göre değişebilir.',
        ),
        _LegalSection(
          title: 'Etkinlik ve konum verileri',
          body:
              'Etkinlik oluştururken başlık, açıklama, spor türü, şehir, ilçe, tarih/saat, kapasite, katılım durumu, host/katılımcı rolü, adres veya buluşma noktası, isteğe bağlı konum koordinatları ve işletme etkinliği fiyat bilgisi gibi alanlar işlenebilir. Konum bilgisi kullanıcının etkinlik konumu eklemesi, mevcut konumu kullanması veya harita uygulamasında konumu açması için kullanılır.',
        ),
        _LegalSection(
          title: 'Kullanıcı içerikleri',
          body:
              'Etkinlik sohbet mesajları, gönderiler, fotoğraflar, fotoğraf açıklamaları, yorumlar, beğeniler, etkinlik bağlantıları, işletme yorumları ve benzeri kullanıcı içerikleri uygulamanın sosyal ve etkinlik akışlarını çalıştırmak için işlenir. Kullanıcı içerikleri görünürlük ayarlarına, etkinlik katılımına, gizli hesap ayarına ve moderasyon kararlarına göre farklı kullanıcılara gösterilebilir.',
        ),
        _LegalSection(
          title: 'Bildirim ve push token verileri',
          body:
              'Uygulama içi bildirimler ve cihaz izinlerine bağlı push bildirimleri; takip istekleri, etkinlik katılım istekleri, onay/red durumları, işletme etkinliği doğrulama hatırlatmaları ve benzeri hesap/etkinlik akışları için kullanılabilir. Push bildirimi gönderebilmek için Firebase Cloud Messaging cihaz tokenı, kullanıcı hesabıyla ilişkilendirilerek saklanabilir. Tam token değeri kullanıcıya açık alanlarda gösterilmez.',
        ),
        _LegalSection(
          title: 'Güvenlik, bildirme ve moderasyon verileri',
          body:
              'Şikayetler, bildirim nedenleri, açıklamalar, hedef kullanıcı/etkinlik/gönderi/yorum bilgileri, engelleme kayıtları, takip istekleri, güven puanı olayları, oran sınırlama kayıtları ve hesap durumu bilgileri kötüye kullanımı önlemek, topluluk güvenliğini sağlamak ve ihlalleri incelemek için işlenebilir.',
        ),
        _LegalSection(
          title: 'Geri bildirim ve destek verileri',
          body:
              'Kullanıcılar puan, kategori, mesaj, kaynak ekran ve benzeri geri bildirim bilgileri paylaşabilir. Bu veriler hata çözümü, ürün iyileştirme, destek, kapalı test değerlendirmesi ve kötüye kullanım incelemeleri için kullanılabilir.',
        ),
        _LegalSection(
          title: 'İşletme başvurusu ve işletme verileri',
          body:
              'İşletme hesabı veya işletme başvurusu akışlarında işletme adı, işletme kullanıcı adı, kategori, şehir/ilçe, adres, telefon, web sitesi, Instagram, açıklama, başvuru durumu, yönetici notu, doğrulama durumu, logo/kapak URL bilgisi ve işletme etkinlikleri işlenebilir. Bu bilgiler işletme hesabını incelemek, yönetmek ve kullanıcılara göstermek için kullanılabilir.',
        ),
        _LegalSection(
          title: 'İşleme amaçları',
          body:
              'Kişisel veriler; hesap oluşturma ve oturum yönetimi, profil ve etkinlik akışlarını sunma, katılım isteklerini yönetme, sohbet/gönderi/yorum özelliklerini çalıştırma, bildirim gönderme, güvenlik ve moderasyon sağlama, rapor/engelleme araçlarını işletme, destek ve geri bildirimleri değerlendirme, hata çözümü, kötüye kullanımın önlenmesi ve hizmet kalitesinin artırılması amaçlarıyla işlenir.',
        ),
        _LegalSection(
          title: 'Hukuki sebepler',
          body:
              'Veriler; sözleşmenin kurulması ve ifası, kullanıcının talep ettiği hizmetin sunulması, veri sorumlusunun meşru menfaatleri, hukuki yükümlülüklerin yerine getirilmesi ve gerektiğinde bir hakkın tesisi, kullanılması veya korunması gibi KVKK kapsamındaki hukuki sebeplere dayanarak işlenebilir. Açık rıza gerektiren ayrı bir işlem olursa bu rıza genel gizlilik metninin içine gizlenmez; ayrı ve açık bir onay ekranı veya metniyle yönetilir.',
        ),
        _LegalSection(
          title: 'Aktarım yapılabilecek taraflar',
          body:
              'Veriler; uygulamanın çalışması için Supabase Auth, Supabase Database, Supabase Storage ve Supabase Realtime altyapısıyla; push bildirimleri için Firebase Cloud Messaging ile; Google ile giriş için Google OAuth/Supabase Auth akışıyla; konumun harita uygulamasında açılması halinde cihazdaki harita uygulamaları, Apple Maps veya OpenStreetMap gibi harici harita servisleriyle sınırlı olarak paylaşılabilir veya bu servisler üzerinden işlenebilir. Yetkili kurumlara aktarım yalnızca hukuki zorunluluk bulunduğunda yapılır.',
        ),
        _LegalSection(
          title: 'Ödeme, reklam ve analiz durumu',
          body:
              'Mevcut kapalı test sürümünde uygulama içi ödeme, cüzdan, ücretli abonelik veya reklam sistemi bulunmamaktadır. Kod tabanında ödeme sağlayıcısı, cüzdan bakiyesi, Firebase Analytics veya Crashlytics entegrasyonu bulunmamaktadır. İleride bu tür özellikler eklenirse gizlilik metni ve gerekiyorsa ayrı rıza süreçleri güncellenmelidir.',
        ),
        _LegalSection(
          title: 'Saklama süresi ve silme ilkeleri',
          body:
              'Veriler, ilgili hesabın ve uygulama özelliklerinin çalışması için gerekli olduğu sürece saklanır. Hesap silme talebi alındığında herkese açık profil kimliği pasifleştirilebilir, gelecek etkinlikler yayından kaldırılabilir ve sosyal içerikler arşivlenebilir veya anonimleştirilebilir. Güvenlik, kötüye kullanım incelemesi, hukuki yükümlülük, uyuşmazlık çözümü veya zorunlu kayıt saklama sebepleriyle bazı kayıtlar sınırlı süreyle tutulabilir.',
        ),
        _LegalSection(
          title: 'KVKK kapsamındaki haklar',
          body:
              'KVKK kapsamında kişisel verilerinin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, işleme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme, yurt içi veya yurt dışı aktarım yapılan tarafları bilme, eksik veya yanlış işlenen verilerin düzeltilmesini isteme, ilgili şartlar altında silme veya yok etme talep etme, yapılan işlemlerin aktarılan üçüncü kişilere bildirilmesini isteme, otomatik sistemler sonucu aleyhe bir sonuca itiraz etme ve kanuna aykırı işleme nedeniyle zararın giderilmesini talep etme haklarına sahipsin.',
        ),
        _LegalSection(
          title: 'Başvuru ve iletişim',
          body:
              'Veri, gizlilik ve hesap silme taleplerini uygulama içindeki Ayarlar > Hesabımı sil veya Ayarlar > Geri bildirim gönder ekranlarından iletebilirsin. Başvurularda hesap sahipliğini doğrulamak için makul ek bilgi istenebilir. Resmi iletişim ve destek kanalları uygulama içinde veya Match A Man’in resmi sayfalarında paylaşılır.',
        ),
        _LegalSection(
          title: 'Çocuklar ve yaş sınırı',
          body:
              'Match A Man 18 yaş ve üzeri kullanıcılar için tasarlanmıştır. 18 yaşın altındaki kişilerin uygulamayı kullanması amaçlanmaz. Yaşla ilgili yanlış bilgi veya güvenlik riski tespit edilirse hesap erişimi sınırlandırılabilir.',
        ),
        _LegalSection(
          title: 'Güvenlik önlemleri',
          body:
              'Match A Man, kullanıcı verilerini korumak için Supabase yetkilendirme kuralları, hesap oturumu, erişim kontrolleri, RLS politikaları, oran sınırlama, raporlama/engelleme araçları ve gizli anahtarların istemci uygulamaya konulmaması gibi makul teknik ve idari önlemler kullanır. Buna rağmen hiçbir dijital sistem için mutlak güvenlik garantisi verilemez.',
        ),
        _LegalSection(
          title: 'Politika güncellemeleri',
          body:
              'Bu metin zaman zaman güncellenebilir. Önemli gizlilik değişiklikleri uygulama içi bildirim, e-posta, push bildirimi veya benzeri makul yollarla duyurulabilir. Açık rıza gerektiren pazarlama, reklam, analiz veya benzeri yeni işleme faaliyetleri olursa bunlar ayrı onay süreçleriyle yönetilir.',
        ),
      ],
    ),
    LegalInfoType.termsOfUse => const _LegalContent(
      title: 'Match A Man Kullanıcı Sözleşmesi',
      notice:
          'Sürüm: terms_v1_2026_06_10\nSon güncelleme: 10 Haziran 2026\nBu metin kapalı test MVP sürümü için hazırlanmıştır.',
      sections: [
        _LegalSection(
          title: 'Taraflar ve platform açıklaması',
          body:
              'Bu Kullanıcı Sözleşmesi, Match A Man mobil uygulamasını kullanan kişi ile Match A Man platformu arasındaki temel kullanım şartlarını açıklar. Match A Man bir sosyal spor ve etkinlik platformudur; kullanıcıların spor ve sosyal etkinlikler etrafında profil oluşturmasına, etkinlik keşfetmesine, etkinlik oluşturmasına, katılım isteği göndermesine ve topluluk içinde iletişim kurmasına yardımcı olur.',
        ),
        _LegalSection(
          title: 'Yaş ve uygunluk',
          body:
              'Match A Man yalnızca 18 yaş ve üzeri kullanıcılar içindir. 18 yaşın altındaysan veya bulunduğun yerde bu hizmeti kullanman yasal olarak uygun değilse uygulamayı kullanmamalısın.',
        ),
        _LegalSection(
          title: 'Hesap, giriş ve kabul',
          body:
              'Uygulamaya e-posta/şifre veya Google ile giriş yapılabilir. Hesap oluştururken Kullanıcı Sözleşmesi kabul kutusunu işaretlemen istenebilir. Hesap güvenliğinden, giriş bilgilerinin korunmasından ve hesabın üzerinden yapılan işlemlerden sen sorumlusun.',
        ),
        _LegalSection(
          title: 'Profil bilgilerinin doğruluğu',
          body:
              'Kullanıcı adı, profil bilgileri, şehir/ilçe, fotoğraf, açıklama ve etkinliklere ilişkin bilgilerin doğru, güncel ve yanıltıcı olmayacak şekilde paylaşılması beklenir. Başkasının kimliğine bürünmek, sahte profil açmak veya yanıltıcı bilgilerle topluluk güvenini zedelemek yasaktır.',
        ),
        _LegalSection(
          title: 'Etkinlikler ve katılım istekleri',
          body:
              'Kullanıcılar etkinlik oluşturabilir, etkinlik konumu veya buluşma noktası ekleyebilir ve etkinliklere katılım isteği gönderebilir. Etkinlik sahibi veya host, katılım isteklerini etkinliğin amacı, kontenjanı, güvenliği ve topluluk deneyimi gibi makul sebeplerle onaylayabilir ya da reddedebilir.',
        ),
        _LegalSection(
          title: 'Etkinlik katılımı ve kullanıcı sorumluluğu',
          body:
              'Etkinliğe katılmadan önce saat, konum, ulaşım, ekipman, seviye beklentisi, mekan koşulları ve kişisel uygunluk gibi bilgileri kontrol etmelisin. Katılacağını belirttiğin etkinliklere makul özen göstermen, gelemeyeceksen mümkün olduğunca erken haber vermen ve diğer kullanıcıların planlarını gereksiz yere aksatmaman beklenir.',
        ),
        _LegalSection(
          title: 'Spor ve fiziksel aktivite riskleri',
          body:
              'Spor ve fiziksel aktiviteler efor, temas, düşme, sakatlanma, kaza veya sağlık riski içerebilir. Kendi sağlık ve kondisyon durumunu değerlendirmen, gerekirse profesyonel sağlık görüşü alman ve etkinlik sırasında mekan, host ve güvenlik kurallarına uyman gerekir. Acil durumlarda uygulama içi bildirim yerine yerel acil yardım, tesis yetkilileri veya yetkili makamlarla iletişime geçilmelidir.',
        ),
        _LegalSection(
          title: 'Topluluk kuralları ve yasak davranışlar',
          body:
              'Taciz, tehdit, nefret söylemi, ayrımcılık, dolandırıcılık, kimliğe bürünme, spam, hukuka aykırı faaliyet, güvenli olmayan davranışlar, başkalarının kişisel verilerini izinsiz paylaşmak, izinsiz reklam yapmak veya platformun güvenliğini bozmak yasaktır. Topluluk Kuralları bu sözleşmenin tamamlayıcı parçası olarak uygulanabilir.',
        ),
        _LegalSection(
          title: 'Kullanıcı içerikleri',
          body:
              'Profil bilgileri, etkinlik açıklamaları, gönderiler, fotoğraflar, yorumlar ve mesajlar gibi kullanıcı içeriklerinden içeriği paylaşan kullanıcı sorumludur. Match A Man, kuralları ihlal eden, güvenlik riski oluşturan veya başkalarının haklarını ihlal eden içerikleri görünürlükten kaldırabilir, sınırlandırabilir veya incelemeye alabilir.',
        ),
        _LegalSection(
          title: 'Raporlama, engelleme ve moderasyon',
          body:
              'Kullanıcılar rahatsız edici davranışları, etkinlikleri, profilleri, gönderileri veya yorumları bildirebilir ve kullanıcıları engelleyebilir. Match A Man, güvenlik, kötüye kullanım veya kural ihlali durumlarında içerikleri kaldırabilir, etkinlik katılımını sınırlandırabilir, hesabı geçici olarak kısıtlayabilir, askıya alabilir veya gerekli hallerde hesabın kapatılması sürecini başlatabilir.',
        ),
        _LegalSection(
          title: 'Bildirimler',
          body:
              'Match A Man; hesap, profil, etkinlik, katılım isteği, host onayı/reddi, güvenlik, destek, uygulama işleyişi ve topluluk deneyimiyle ilgili uygulama içi bildirimler veya push bildirimleri gönderebilir. Cihaz bildirim izinlerini işletim sistemi ayarlarından yönetebilirsin.',
        ),
        _LegalSection(
          title: 'Flört uygulaması değildir',
          body:
              'Match A Man flört veya dating uygulaması değildir. Platformun amacı kullanıcıları romantik eşleşme için değil, sosyal spor ve etkinlik deneyimleri etrafında bir araya getirmektir. Taciz edici, ısrarcı, cinsel içerikli veya rahatsız edici iletişim topluluk kurallarına aykırıdır.',
        ),
        _LegalSection(
          title: 'Kapalı test ve ödeme durumu',
          body:
              'Mevcut kapalı test sürümünde uygulama içi ödeme, cüzdan veya ücretli biletleme sunulmamaktadır. Bazı işletme etkinliklerinde fiyat bilgisi görüntülenebilir; bu bilgi uygulama içi tahsilat, cüzdan bakiyesi, satın alma veya iade süreci anlamına gelmez. İleride ücretli özellikler eklenirse ayrı ödeme şartları, bilgilendirmeler veya politikalar yayımlanabilir.',
        ),
        _LegalSection(
          title: 'İşletme hesapları',
          body:
              'Uygulamada işletme başvurusu ve işletme profili akışları bulunabilir. İşletme hesabı kullanan kişiler; işletme bilgileri, etkinlik açıklamaları, mekan koşulları, fiyat bilgisi, hizmet iddiaları ve yasal uygunluk gibi konularda doğru ve yanıltıcı olmayan bilgi paylaşmalıdır. Match A Man, işletme başvurularını inceleyebilir ve uygun görmediği hesapları sınırlandırabilir.',
        ),
        _LegalSection(
          title: 'Fikri mülkiyet',
          body:
              'Match A Man adı, arayüzü, yazılımı, görsel kimliği, metinleri ve platforma ait teknik bileşenler ilgili hak sahiplerine aittir. Kullanıcılar platformu kopyalayamaz, tersine mühendislik yapamaz, yetkisiz erişim denemesi yapamaz veya platformun güvenliğini ve işleyişini bozacak araçlar kullanamaz.',
        ),
        _LegalSection(
          title: 'Hizmetin kullanılabilirliği',
          body:
              'Kapalı test ve MVP sürümü hata, kesinti, gecikme, eksik özellik veya beklenmeyen davranışlar içerebilir. Match A Man hizmeti güvenli ve kullanılabilir tutmak için makul çabayı gösterir; ancak uygulamanın her zaman kesintisiz, hatasız veya tüm cihazlarda aynı şekilde çalışacağı garanti edilmez.',
        ),
        _LegalSection(
          title: 'Sorumluluğun sınırları',
          body:
              'Match A Man, kullanıcıların kendi içerikleri, etkinlik kararları, fiziksel katılım tercihleri, kullanıcılar arası iletişimleri ve üçüncü taraf mekan/işletme koşulları üzerinde tam kontrol sahibi değildir. Yürürlükteki zorunlu tüketici hakları ve emredici mevzuat saklı kalmak üzere, platformun sorumluluğu makul ve hukuken izin verilen sınırlar içinde değerlendirilir.',
        ),
        _LegalSection(
          title: 'Sözleşme Değişiklikleri',
          body:
              'Match A Man bu sözleşmeyi zaman zaman güncelleyebilir. Güncel sözleşme uygulama içinde veya resmi sayfalarda yayımlanır. Önemli değişiklikler uygulama içi bildirim, e-posta, push bildirimi veya benzeri makul yöntemlerle duyurulabilir ve kullanıcıya değişiklikleri inceleme fırsatı verilir. Kullanıcı, önemli bir değişikliğin yürürlük tarihinden sonra uygulamayı kullanmaya devam ederse güncel şartları kabul etmiş sayılabilir. Bir değişiklik hukuken veya teknik olarak yeniden açık kabul gerektirirse, uygulamaya devam etmek için kullanıcıdan güncellenen şartları kabul etmesi istenebilir. Güncellenen şartları kabul etmeyen kullanıcı uygulamayı kullanmayı bırakabilir ve hesap silme talebinde bulunabilir. KVKK, Gizlilik Politikası, Aydınlatma Metni veya açık rıza gerektiren değişiklikler bu sözleşmenin içine gizlenmez; gerekli hallerde ayrı metinler veya onay ekranları üzerinden yönetilir.',
        ),
        _LegalSection(
          title: 'Hesap silme ve sona erme',
          body:
              'Kullanıcılar uygulama içindeki hesap silme veya destek kanallarını kullanarak hesaplarına ilişkin taleplerini iletebilir. Match A Man, kural ihlali, güvenlik riski, kötüye kullanım veya hukuki zorunluluk halinde hesap erişimini sınırlandırabilir ya da hesabı askıya alabilir. Hesap silme ve veri saklama süreçleri geçerli mevzuat, güvenlik kayıtları ve zorunlu saklama süreleri dikkate alınarak yürütülür.',
        ),
        _LegalSection(
          title: 'Uygulanacak hukuk',
          body:
              'Bu sözleşmenin yorumlanmasında Türkiye Cumhuriyeti hukuku uygulanır. Tüketici hakları, zorunlu yetki kuralları ve yürürlükteki emredici mevzuattan doğan haklar saklıdır.',
        ),
        _LegalSection(
          title: 'İletişim ve destek',
          body:
              'Destek, güvenlik, geri bildirim, hesap ve veri talepleri için uygulama içindeki destek ve geri bildirim kanallarını kullanabilirsin. Resmi iletişim kanalları uygulama içinde veya Match A Man tarafından duyurulan resmi sayfalarda yayımlanabilir.',
        ),
      ],
    ),
    LegalInfoType.communityGuidelines => const _LegalContent(
      title: 'Topluluk Kuralları',
      notice:
          'Bu kurallar, etkinlik odaklı ve güvenli bir spor topluluğu deneyimi için geçerlidir.',
      sections: [
        _LegalSection(
          title: 'Saygılı iletişim',
          body:
              'Kullanıcılar birbirine saygılı davranmalı, taciz, aşağılama, tehdit, nefret söylemi, ayrımcılık, istenmeyen cinsel içerik veya rahatsız edici mesajlardan kaçınmalıdır.',
        ),
        _LegalSection(
          title: 'Güvenli etkinlik kültürü',
          body:
              'Etkinlik açıklamaları doğru, anlaşılır ve güvenli olmalıdır. Katılım istekleri, onay, red, bekleme listesi, ayrılma ve check-in süreçleri kötüye kullanılmamalıdır.',
        ),
        _LegalSection(
          title: 'Yasak içerikler',
          body:
              'Hukuka aykırı, zararlı, yanıltıcı, sahte, şiddet içeren, cinsel, nefret içerikli, dolandırıcılık amaçlı, spam veya başkalarının özel hayatını ihlal eden içerikler yasaktır.',
        ),
        _LegalSection(
          title: 'Şikayet ve engelleme',
          body:
              'Rahatsız edici kullanıcıları engelleyebilir; kullanıcı, gönderi, yorum veya etkinlikleri bildirebilirsin. Bildirimler incelenir ancak her bildirim için anlık müdahale garanti edilmez.',
        ),
      ],
    ),
    LegalInfoType.eventSafetyDisclaimer => const _LegalContent(
      title: 'Etkinlik Güvenliği ve Sorumluluk Bilgilendirmesi',
      notice:
          'Etkinliklere katılım kararı ve hazırlığı kullanıcının kendi değerlendirmesine bağlıdır.',
      sections: [
        _LegalSection(
          title: 'Kendi riskinle katılım',
          body:
              'Match A Man üzerinde oluşturulan etkinliklere katılım kullanıcının kendi değerlendirmesi ve sorumluluğundadır. Platform etkinlikleri fiziksel olarak denetlemez, organize etmez, garanti etmez veya sigortalamaz.',
        ),
        _LegalSection(
          title: 'Kontrol listesi',
          body:
              'Etkinliğe gitmeden önce konumu, saati, ulaşımı, mekan kurallarını, katılımcı profilini, spor seviyesini, hava durumunu, ekipman ihtiyacını ve kişisel sağlık uygunluğunu kontrol etmelisin.',
        ),
        _LegalSection(
          title: 'Acil durumlar',
          body:
              'Tehlike, kaza, taciz, şiddet, tehdit veya acil sağlık durumlarında uygulama içi bildirim yeterli olmayabilir. Öncelikle yerel acil yardım, güvenlik görevlileri veya yetkili makamlarla iletişime geçmelisin.',
        ),
        _LegalSection(
          title: 'Platform sorumluluğu',
          body:
              'Yürürlükteki hukukun izin verdiği en geniş ölçüde platform; yaralanma, kaza, kavga, hırsızlık, taciz, eşya hasarı, ulaşım problemi, mekan sorunu, iptal, gelmeme veya kullanıcılar arası anlaşmazlıklardan sorumlu değildir.',
        ),
        _LegalSection(
          title: 'İşletme etkinlikleri',
          body:
              'İşletme etkinliklerinde hizmet, fiyat, mekan, ekipman, kontenjan, güvenlik, vaat edilen imkanlar ve yasal uygunluk ilgili işletme hesabının sorumluluğundadır.',
        ),
      ],
    ),
    LegalInfoType.support => const _LegalContent(
      title: 'Match A Man Hesap Silme Bilgilendirmesi',
      notice:
          'Sürüm: account_deletion_v1_2026_06_10\nSon güncelleme: 10 Haziran 2026\nBu metin hesap silme, veri talepleri ve destek kanalları için kapalı test MVP bilgilendirmesidir.',
      sections: [
        _LegalSection(
          title: 'Uygulama içinden hesap silme talebi',
          body:
              'Hesabını silmek için uygulama içinde Ayarlar > Hesabımı sil yolunu kullanabilirsin. Bu ekranda devam etmek için SİL yazarak hesabın için silme talebi oluşturursun. Talep oluşturulduğunda oturumun kapatılır ve hesap silme/deaktivasyon süreci başlatılır.',
        ),
        _LegalSection(
          title: 'Talep sonrası işleyiş',
          body:
              'Mevcut kapalı test sürümünde hesap silme işlemi anlık fiziksel silme olarak tamamlanmayabilir. Talep alındıktan sonra herkese açık profil kimliğin pasifleştirilebilir, profil görünürlüğün kapatılabilir, gelecek etkinliklerin yayından kaldırılabilir ve nihai veri silme/anonimleştirme işlemi kısa bir inceleme veya manuel backend süreci sonrasında tamamlanabilir.',
        ),
        _LegalSection(
          title: 'Silinen veya anonimleştirilen veriler',
          body:
              'Hesap silme sürecinde profil bilgileri, herkese açık kullanıcı kimliği, avatar/profil görünürlüğü, gelecek etkinlikler, bazı sosyal içerikler, takip görünürlüğü ve hesapla ilişkilendirilen aktif kullanım kayıtları silinebilir, arşivlenebilir, pasifleştirilebilir veya anonimleştirilebilir. Silme yöntemi verinin türüne, görünürlüğüne ve güvenlik/uyuşmazlık ihtiyacına göre değişebilir.',
        ),
        _LegalSection(
          title: 'Sınırlı süre saklanabilecek veriler',
          body:
              'Güvenlik, kötüye kullanımın önlenmesi, rapor veya şikayet incelemesi, hukuki yükümlülük, uyuşmazlık çözümü, dolandırıcılık veya sistem bütünlüğü gibi meşru sebeplerle bazı kayıtlar sınırlı süreyle saklanabilir. Bu kapsamda raporlar, engelleme ve moderasyon kayıtları, güvenlik olayları, zorunlu işlem kayıtları ve destek yazışmaları hemen silinmeyebilir.',
        ),
        _LegalSection(
          title: 'Geçici pasifleştirme ve silme farkı',
          body:
              'Hesabın geçici olarak pasifleştirilmesi, gizlenmesi, askıya alınması veya işletme modunun kapatılması nihai hesap silme ile aynı şey değildir. Hesap silme talebi, kullanıcı hesabının kapatılması ve ilgili kişisel verilerin silinmesi ya da anonimleştirilmesi için ayrı bir süreçtir.',
        ),
        _LegalSection(
          title: 'İşletme hesabı silme',
          body:
              'İşletme hesabı kullanıyorsan Ayarlar > İşletme hesabımı sil akışı işletme modunu pasifleştirir ve hesabın kullanıcı hesabı olarak devam edebilir. Bu işlem, kullanıcı hesabının tamamen silinmesiyle aynı değildir. Kullanıcı hesabının tamamen silinmesi için ayrıca Ayarlar > Hesabımı sil yolunu kullanmalısın.',
        ),
        _LegalSection(
          title: 'Veri erişim ve düzeltme talepleri',
          body:
              'Kişisel verilerine erişim, düzeltme, silme, itiraz veya KVKK kapsamındaki diğer taleplerini uygulama içindeki Ayarlar > Geri bildirim gönder ekranından iletebilirsin. Hesap sahipliğini doğrulamak için makul ek bilgi istenebilir. Resmi iletişim ve destek kanalları uygulama içinde veya Match A Man’in resmi sayfalarında paylaşılır.',
        ),
        _LegalSection(
          title: 'Uygulama dışı başvuru ve destek',
          body:
              'Uygulamaya erişemiyorsan, resmi destek kanalı üzerinden hesap e-postanı, kullanıcı adını biliyorsan kullanıcı adını ve talebinin hesap silme mi yoksa veri talebi mi olduğunu paylaşarak başvuru yapabilirsin. Resmi iletişim ve destek kanalları uygulama içinde veya Match A Man’in resmi sayfalarında paylaşılır.',
        ),
      ],
    ),
  };
}

class _LegalContent {
  const _LegalContent({
    required this.title,
    required this.notice,
    required this.sections,
  });

  final String title;
  final String notice;
  final List<_LegalSection> sections;
}

class _LegalSection {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;
}
