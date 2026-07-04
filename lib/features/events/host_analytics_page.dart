import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/error_view.dart';
import 'events_models.dart';
import 'events_provider.dart';

class HostAnalyticsPage extends ConsumerWidget {
  const HostAnalyticsPage({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(hostEventAnalyticsProvider(eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Katılım Analizi')),
      body: SafeArea(
        child: analyticsAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) {
            final errorStr = error.toString().toLowerCase();
            final isNotAuthorized =
                errorStr.contains('not_authorized_host_only') ||
                errorStr.contains('not_authorized') ||
                errorStr.contains('yetkisiz');
            return ErrorView(
              message: isNotAuthorized
                  ? 'Bu etkinliğin analizlerini görüntüleme yetkiniz yok.'
                  : 'Analizler yüklenemedi. Lütfen daha sonra tekrar deneyin.',
              onRetry: () =>
                  ref.invalidate(hostEventAnalyticsProvider(eventId)),
            );
          },
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Yoklaması alınmış veya katılan aktif katılımcı bulunmuyor.',
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length + 1,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(eventTitle, style: AppTextStyles.title),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Katılımcıların etkinlikteki mesaj sayıları ve giriş saatleri.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  );
                }

                final item = list[index - 1];
                return _AnalyticsTile(item: item);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({required this.item});

  final EventParticipantAnalytics item;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = item.avatarUrl;
    final trimmedName = item.displayName.trim();
    final fallback = trimmedName.isEmpty
        ? '?'
        : trimmedName.substring(0, 1).toUpperCase();

    final formattedJoined = _formatDateTime(item.joinedAt);
    final formattedCheckIn = item.checkedInAt != null
        ? _formatDateTime(item.checkedInAt!)
        : 'Yoklama Alınmadı';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: avatarUrl == null || avatarUrl.trim().isEmpty
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl == null || avatarUrl.trim().isEmpty
                  ? Text(
                      fallback,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: AppTextStyles.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Katılım: $formattedJoined',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Yoklama: $formattedCheckIn',
                    style: AppTextStyles.caption.copyWith(
                      color: item.checkedInAt != null
                          ? AppColors.success
                          : AppColors.textMuted,
                      fontWeight: item.checkedInAt != null
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      '${item.messageCount} mesaj',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime val) {
    final value = val.toLocal();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}.${value.month}.${value.year} $hour:$minute';
  }
}
