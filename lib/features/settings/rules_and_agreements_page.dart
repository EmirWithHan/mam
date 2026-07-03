import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_logo.dart';
import 'widgets/settings_menu_tile.dart';

class RulesAndAgreementsPage extends StatelessWidget {
  const RulesAndAgreementsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
            context.goNamed(RouteNames.settings);
          },
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text('Kurallar ve sözleşmeler', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Akanzi’i güvenli ve şeffaf şekilde kullanabilmen için temel kuralları ve sözleşmeleri burada topladık.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsMenuTile(
              icon: Icons.description_outlined,
              title: 'Kullanıcı Sözleşmesi',
              subtitle: 'Kullanım şartları ve kullanıcı sorumlulukları',
              onTap: () => context.pushNamed(RouteNames.termsOfUse),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik Politikası',
              subtitle: 'Veri kullanımı ve gizlilik tercihleri',
              onTap: () => context.pushNamed(RouteNames.privacyPolicy),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.groups_outlined,
              title: 'Topluluk Kuralları',
              subtitle: 'Güvenli ve saygılı etkinlik topluluğu',
              onTap: () => context.pushNamed(RouteNames.communityGuidelines),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Etkinlik Güvenliği',
              subtitle: 'Spor etkinlikleri için güvenlik bilgilendirmesi',
              onTap: () => context.pushNamed(RouteNames.eventSafetyDisclaimer),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsMenuTile(
              icon: Icons.support_agent_outlined,
              title: 'Hesap ve veri talepleri',
              subtitle: 'Destek, güvenlik ve hesap talepleri',
              onTap: () => context.pushNamed(RouteNames.support),
            ),
          ],
        ),
      ),
    );
  }
}
