import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_logo.dart';

enum LegalInfoType { privacyPolicy, termsOfUse, communityGuidelines, support }

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({super.key, required this.type});

  final LegalInfoType type;

  @override
  Widget build(BuildContext context) {
    final content = _content(type);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
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
          'MVP taslak metindir. Gerçek mağaza gönderimi öncesi profesyonel hukuki inceleme gerekir.',
      sections: [
        _LegalSection(
          title: 'Toplanan bilgiler',
          body:
              'Match A Man hesap, profil, etkinlik, paylaşım, geri bildirim ve güvenlik/moderasyon için gerekli bilgileri işler. Konum yalnızca etkinlik konumunu doldurmak için kullanıcı isteğiyle alınır.',
        ),
        _LegalSection(
          title: 'Kullanım amacı',
          body:
              'Bilgiler kimlik doğrulama, etkinlik akışı, sosyal güvenlik, destek, raporlama ve uygulama güvenilirliği için kullanılır.',
        ),
        _LegalSection(
          title: 'Kontrol',
          body:
              'Profil gizliliği, engelleme, raporlama ve işletme hesabını pasifleştirme seçenekleri Ayarlar ve ilgili ekranlardan yönetilir.',
        ),
      ],
    ),
    LegalInfoType.termsOfUse => const _LegalContent(
      title: 'Kullanım Şartları',
      notice:
          'MVP taslak metindir. Final kullanım şartları hukuki inceleme sonrası yayınlanmalıdır.',
      sections: [
        _LegalSection(
          title: 'Uygulama amacı',
          body:
              'Match A Man spor ve sosyal etkinlikleri keşfetmek, oluşturmak ve katılımcılarla iletişim kurmak için kullanılan etkinlik merkezli bir uygulamadır.',
        ),
        _LegalSection(
          title: 'Kullanıcı sorumluluğu',
          body:
              'Kullanıcılar doğru profil bilgisi vermeli, diğer kişilere saygılı davranmalı ve güvenli buluşma kurallarına uymalıdır.',
        ),
        _LegalSection(
          title: 'Hesap ve içerik',
          body:
              'Kuralları ihlal eden hesaplar, etkinlikler veya paylaşımlar raporlanabilir, sınırlandırılabilir ya da kaldırılabilir.',
        ),
      ],
    ),
    LegalInfoType.communityGuidelines => const _LegalContent(
      title: 'Topluluk Kuralları',
      notice:
          'MVP topluluk özeti. Mağaza gönderimi öncesi güvenlik ve moderasyon metni netleştirilmelidir.',
      sections: [
        _LegalSection(
          title: 'Saygılı ol',
          body:
              'Taciz, nefret söylemi, tehdit, spam, sahte etkinlik ve yanıltıcı profil bilgisi kabul edilmez.',
        ),
        _LegalSection(
          title: 'Güvenli etkinlikler',
          body:
              'Etkinlik bilgileri açık olmalı; katılım, onay, iptal ve check-in süreçleri kötüye kullanılmamalıdır.',
        ),
        _LegalSection(
          title: 'Raporla ve engelle',
          body:
              'Rahatsız edici kullanıcıları engelleyebilir, kullanıcı/profil/içerik/etkinlik sorunlarını raporlayabilirsin.',
        ),
      ],
    ),
    LegalInfoType.support => const _LegalContent(
      title: 'Bize Ulaş / Destek',
      notice:
          'MVP destek bilgisi. Final destek e-postası ve yanıt süresi mağaza öncesi netleştirilmelidir.',
      sections: [
        _LegalSection(
          title: 'Uygulama içi destek',
          body:
              'Ayarlar > Geri bildirim gönder ekranından deneyimini, hata bildirimini veya önerini iletebilirsin.',
        ),
        _LegalSection(
          title: 'Güvenlik konuları',
          body:
              'Acil güvenlik, taciz veya sahte etkinlik konularında ilgili kullanıcıyı ya da içeriği raporla ve gerekirse engelle.',
        ),
        _LegalSection(
          title: 'Hesap silme',
          body:
              'MVP içinde işletme hesabını pasifleştirme vardır. Tam kullanıcı hesabı silme ve veri talep süreci final yasal metinle tamamlanmalıdır.',
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
