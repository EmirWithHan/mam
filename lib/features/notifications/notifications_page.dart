import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_logo.dart';
import 'widgets/notification_tile.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            Text('Bildirimler', style: AppTextStyles.headline),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Son gelişmeler ve güncellemeler',
              style: AppTextStyles.body,
            ),
            SizedBox(height: AppSpacing.lg),
            NotificationTile(
              title: 'Ahmet Yılmaz, yarınki Sabah Koşusu etkinliğine katıldı.',
              timeLabel: '5 dk önce',
              type: 'Etkinlik',
              icon: Icons.directions_run,
              highlighted: true,
            ),
            SizedBox(height: AppSpacing.md),
            NotificationTile(
              title: 'Zeynep Kaya seni takip etmeye başladı.',
              timeLabel: '18 dk önce',
              type: 'Topluluk',
              icon: Icons.person_add_alt_1,
            ),
            SizedBox(height: AppSpacing.md),
            NotificationTile(
              title: 'Sistem Güncellemesi',
              message:
                  'Yeni özellikler ve performans iyileştirmeleri yayında.',
              timeLabel: 'Bugün',
              type: 'MaM',
              icon: Icons.auto_awesome,
              highlighted: true,
            ),
            SizedBox(height: AppSpacing.md),
            NotificationTile(
              title:
                  'Hafta Sonu Bisiklet Turu etkinliğin detayları güncellendi.',
              timeLabel: 'Dün',
              type: 'Etkinlik',
              icon: Icons.directions_bike,
            ),
            SizedBox(height: AppSpacing.md),
            NotificationTile(
              title: 'Can son yürüyüş rotanı beğendi.',
              timeLabel: '2 gün önce',
              type: 'Feed',
              icon: Icons.favorite_border,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'Bildirim sistemi yakında gerçek zamanlı hale gelecek.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.home);
  }
}
