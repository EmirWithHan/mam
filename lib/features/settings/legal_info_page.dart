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
      title: 'Gizlilik Politikası',
      notice:
          'Bu metin MVP taslağıdır. Yayın öncesi avukat veya hukuk danışmanı tarafından incelenmelidir.',
      sections: [
        _LegalSection(
          title: 'Toplanan bilgiler',
          body:
              'Match A Man; hesap oluşturma, Supabase Auth oturumu, profil bilgileri, kullanıcı adı, avatar, şehir/ilçe, etkinlik katılımı, gönderiler, yorumlar, takip ilişkileri, bildirimler, işletme başvuruları, geri bildirimler, şikayetler ve engelleme kayıtları gibi uygulamanın çalışması için gerekli verileri işler.',
        ),
        _LegalSection(
          title: 'Konum ve medya',
          body:
              'Konum bilgisi yalnızca kullanıcı etkinlik konumu eklemek veya harita yardımı almak istediğinde kullanılır. Fotoğraf ve medya yüklemeleri kullanıcı tarafından başlatılır. Kamera veya galeri erişimi, ilgili işlem yapılmadan istenmez.',
        ),
        _LegalSection(
          title: 'Kullanım amacı',
          body:
              'Veriler kimlik doğrulama, profil ve etkinlik akışı, katılım istekleri, güvenlik, topluluk moderasyonu, bildirimler, destek, hata çözümü, kötüye kullanımın önlenmesi ve hizmet kalitesinin artırılması amacıyla kullanılır.',
        ),
        _LegalSection(
          title: 'Paylaşım ve görünürlük',
          body:
              'Profil, gönderi, etkinlik, takip ve yorum görünürlüğü uygulamadaki gizlilik ayarlarına ve güvenlik kurallarına göre değişebilir. E-posta, telefon, auth metadata ve moderasyon alanları herkese açık profil veya arama sonuçlarında gösterilmez.',
        ),
        _LegalSection(
          title: 'Kullanıcı kontrolü',
          body:
              'Kullanıcılar profil bilgilerini güncelleyebilir, gizli hesap ayarını değiştirebilir, kullanıcıları engelleyebilir, içerikleri bildirebilir ve işletme hesabı durumunu yönetebilir. Tam hesap silme ve veri talepleri yayın öncesi yasal süreçle netleştirilmelidir.',
        ),
        _LegalSection(
          title: 'Gelecek özellikler',
          body:
              'Telefon doğrulama/OTP, ödeme ve anlık push bildirimleri aktif değilse bu veriler veya izinler zorunlu tutulmaz. Bu özellikler ileride eklenirse gizlilik metni güncellenmelidir.',
        ),
      ],
    ),
    LegalInfoType.termsOfUse => const _LegalContent(
      title: 'Kullanım Şartları',
      notice:
          'Bu metin MVP taslağıdır. Nihai yasal metin değildir; yayın öncesi avukat veya hukuk danışmanı tarafından incelenmelidir.',
      sections: [
        _LegalSection(
          title: 'Şartları kabul',
          body:
              'Match A Man hesabı oluşturduğunuzda, uygulamayı kullandığınızda, etkinlik oluşturduğunuzda, etkinliğe katılmak istediğinizde, gönderi veya yorum paylaştığınızda bu kullanım şartlarını kabul etmiş sayılırsınız. Şartları kabul etmiyorsanız uygulamayı kullanmayı bırakmalısınız.',
        ),
        _LegalSection(
          title: 'Platformun rolü',
          body:
              'Match A Man spor ve sosyal etkinlikleri keşfetmek, oluşturmak, katılım isteği göndermek ve diğer kullanıcılarla uygulama içinde iletişim kurmak için aracılık sağlayan bir platformdur. Platform, kullanıcılar tarafından oluşturulan etkinliklerin doğrudan düzenleyicisi, gözetmeni, sigortacısı, güvenlik sağlayıcısı veya fiziksel kontrol sorumlusu değildir.',
        ),
        _LegalSection(
          title: 'Etkinliklere katılım riski',
          body:
              'Kullanıcılar etkinlik oluşturma ve etkinliklere katılma kararını kendi sorumluluğunda verir. Etkinlik detaylarını, konumu, saatleri, katılımcıları, ulaşımı, mekan koşullarını, fiziksel uygunluğu ve güvenlik durumunu kontrol etmek kullanıcının sorumluluğundadır. Spor aktiviteleri sakatlanma ve kaza riski taşıyabilir.',
        ),
        _LegalSection(
          title: 'Sorumluluk sınırı',
          body:
              'Yürürlükteki hukukun izin verdiği en geniş ölçüde; yaralanma, kaza, kavga, hırsızlık, taciz, mal kaybı, eşya hasarı, ulaşım sorunu, mekan problemi, iptal, geç kalma, gelmeme, kullanıcılar arası anlaşmazlık, yanlış veya eksik etkinlik bilgisi gibi durumlardan platform sorumlu tutulamaz.',
        ),
        _LegalSection(
          title: 'Kullanıcı davranışı',
          body:
              'Kullanıcılar yasalara, mekan kurallarına, spor güvenliği kurallarına ve topluluk kurallarına uymalıdır. Hukuka aykırı, zararlı, nefret içerikli, cinsel, şiddet içeren, tehditkar, taciz edici, dolandırıcı, yanıltıcı veya başkalarının haklarını ihlal eden içerik paylaşmak yasaktır.',
        ),
        _LegalSection(
          title: 'Kimlik ve hesap kullanımı',
          body:
              'Başkasının kimliğine bürünmek, yanıltıcı profil oluşturmak, sahte etkinlik açmak, başka kullanıcıları kandırmak, güven puanı veya katılım süreçlerini kötüye kullanmak yasaktır. Bir hesap, bir profil ve tek bir kamusal kimlik prensibi korunur.',
        ),
        _LegalSection(
          title: 'İşletme hesapları',
          body:
              'İşletme hesabı açan kullanıcılar işletme bilgileri, fiyatlar, hizmet iddiaları, mekan koşulları, etkinlik açıklamaları, vergi/yasal uygunluk ve müşteri ilişkilerinden kendileri sorumludur. İşletme hesaplarının kötüye kullanılması, yanıltıcı tanıtım yapılması veya uygunsuz etkinlik açılması hesabın kısıtlanmasına yol açabilir.',
        ),
        _LegalSection(
          title: 'Moderasyon ve güvenlik',
          body:
              'Platform; güvenlik, kötüye kullanım, şikayet, hukuki risk veya topluluk ihlali durumlarında içerikleri kaldırabilir, etkinlikleri gizleyebilir, hesapları kısıtlayabilir, işletme başvurularını reddedebilir veya işletme hesaplarını askıya alabilir. Şikayetler incelenir ancak anında işlem garantisi verilmez.',
        ),
        _LegalSection(
          title: 'Ödeme, OTP ve push durumu',
          body:
              'Ücretli/ödeme özellikleri açıkça uygulanmadıkça aktif değildir. Telefon doğrulama veya OTP ertelenmiş olabilir. Firebase veya push bildirimleri aktif değilse kullanıcılar yalnızca uygulama içi bildirimleri görebilir.',
        ),
        _LegalSection(
          title: 'Değişiklikler',
          body:
              'Kullanım şartları zaman içinde güncellenebilir. Önemli değişiklikler uygulama içinde veya uygun başka kanallarla duyurulabilir. Güncellenen şartları kabul etmeyen kullanıcı uygulamayı kullanmayı bırakmalıdır.',
        ),
      ],
    ),
    LegalInfoType.communityGuidelines => const _LegalContent(
      title: 'Topluluk Kuralları',
      notice:
          'Bu metin MVP taslağıdır. Yayın öncesi güvenlik ve hukuk incelemesi gerekir.',
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
      title: 'Etkinlik Güvenliği ve Sorumluluk Reddi',
      notice:
          'Bu metin MVP taslağıdır. Yayın öncesi avukat veya hukuk danışmanı tarafından incelenmelidir.',
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
      title: 'Bize Ulaş / Destek',
      notice:
          'Bu metin MVP taslağıdır. Final destek kanalları yayın öncesi netleştirilmelidir.',
      sections: [
        _LegalSection(
          title: 'Uygulama içi destek',
          body:
              'Ayarlar > Geri bildirim gönder ekranından hata, öneri veya deneyim notunu iletebilirsin.',
        ),
        _LegalSection(
          title: 'Güvenlik konuları',
          body:
              'Taciz, sahte etkinlik, dolandırıcılık, tehdit veya güvenlik riski gördüğünde ilgili kullanıcıyı, etkinliği, gönderiyi veya yorumu bildir ve gerekirse kullanıcıyı engelle.',
        ),
        _LegalSection(
          title: 'Hesap talepleri',
          body:
              'MVP içinde işletme hesabını pasifleştirme akışı bulunur. Tam kullanıcı hesabı silme ve veri talep süreci yayın öncesi yasal metinlerle tamamlanmalıdır.',
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
