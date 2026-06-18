import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/empty_state.dart';
import 'notifications_models.dart';
import 'notifications_provider.dart';
import 'widgets/notification_tile.dart';

class FollowRequestsPage extends ConsumerStatefulWidget {
  const FollowRequestsPage({super.key});

  @override
  ConsumerState<FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends ConsumerState<FollowRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final pendingRequests = state.notifications
        .where((n) => n.isFollowRequest && n.canRespondToFollowRequest)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Geri',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Takip İstekleri', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref
              .read(notificationsControllerProvider.notifier)
              .refreshNotifications(),
          child: pendingRequests.isEmpty
              ? const EmptyState(
                  title: 'Takip isteği yok.',
                  message: 'Bekleyen takip isteğiniz bulunmamaktadır.',
                  icon: Icons.person_outline_rounded,
                )
              : ListView.builder(
                  padding: AppResponsive.pagePadding(context),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = pendingRequests[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: NotificationTile(
                        notification: request,
                        timeLabel: DateFormatter.relativeTime(
                          request.createdAt,
                        ),
                        isBusy: state.isUpdating,
                        onTap: () => _handleTap(request),
                        onApprove: () => _approveRequest(request),
                        onReject: () => _rejectRequest(request),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _handleTap(AppNotification request) {
    final actorId = request.actorId;
    if (actorId != null && actorId.isNotEmpty) {
      context.pushNamed('publicProfile', pathParameters: {'userId': actorId});
    }
  }

  Future<void> _approveRequest(AppNotification request) async {
    final success = await ref
        .read(notificationsControllerProvider.notifier)
        .approveFollowRequest(request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Takip isteği onaylandı.' : 'İstek işlenemedi.',
        ),
      ),
    );
  }

  Future<void> _rejectRequest(AppNotification request) async {
    final success = await ref
        .read(notificationsControllerProvider.notifier)
        .rejectFollowRequest(request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Takip isteği reddedildi.' : 'İstek işlenemedi.',
        ),
      ),
    );
  }
}
