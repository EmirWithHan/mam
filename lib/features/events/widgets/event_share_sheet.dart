import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_loader.dart';
import '../../auth/auth_provider.dart';
import '../../direct_messages/direct_messages_provider.dart';
import '../events_models.dart';

class EventShareSheet extends ConsumerStatefulWidget {
  const EventShareSheet({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends ConsumerState<EventShareSheet> {
  final Set<String> _sentConversationIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(directInboxProvider.notifier).loadInbox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(directInboxProvider);
    final myUserId = ref.watch(authControllerProvider).userId;
    final shareText = _buildShareText(widget.event);

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Etkinliği Paylaş',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Share.share(shareText);
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Dışarıda Paylaş (WhatsApp, SMS vb.)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            Text('Uygulama İçi Gönder (DM)', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: _buildInboxContent(inboxState, myUserId, shareText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxContent(
    DirectInboxState inboxState,
    String? myUserId,
    String shareText,
  ) {
    if (inboxState.loading && inboxState.conversations.isEmpty) {
      return const SizedBox(height: 120, child: Center(child: AppLoader()));
    }

    if (inboxState.isUnavailable) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Mesajlaşma şu anda kullanılamıyor.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (inboxState.conversations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'Aktif sohbetiniz bulunmamaktadır.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: inboxState.conversations.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, index) {
        final conv = inboxState.conversations[index];
        final other = conv.getOtherParticipant(myUserId);
        if (other == null) return const SizedBox.shrink();

        final sent = _sentConversationIds.contains(conv.id);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              other.avatarUrl != null && other.avatarUrl!.trim().isNotEmpty
                  ? CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(other.avatarUrl!),
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primarySoft,
                      child: Text(
                        other.displayName.isNotEmpty
                            ? other.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  other.displayName,
                  style: AppTextStyles.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 96,
                height: 36,
                child: FilledButton(
                  onPressed: sent
                      ? null
                      : () async {
                          final success = await ref
                              .read(
                                directChatControllerProvider(conv.id).notifier,
                              )
                              .sendMessage(shareText);
                          if (success) {
                            setState(() {
                              _sentConversationIds.add(conv.id);
                            });
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: sent
                        ? AppColors.border
                        : AppColors.primary,
                    foregroundColor: sent ? AppColors.textMuted : Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    sent ? 'Gönderildi' : 'Gönder',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildShareText(Event event) {
    final typeStr = event.sportType ?? 'Etkinlik';
    final dateStr = _formatDateTime(event.eventDate);
    final locationStr = [
      event.city,
      if (event.district != null && event.district!.trim().isNotEmpty)
        event.district!.trim(),
      if (event.locationText != null && event.locationText!.trim().isNotEmpty)
        event.locationText!.trim(),
    ].join(' / ');

    return 'Akanzi\'de bir etkinlik buldum: ${event.titleLabel}\n'
        'Tür: $typeStr\n'
        'Tarih: $dateStr\n'
        'Konum: $locationStr\n'
        'Etkinlik ID: ${event.id}\n'
        'Ayrıntılar için Akanzi uygulamasını ziyaret edebilirsin!';
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
