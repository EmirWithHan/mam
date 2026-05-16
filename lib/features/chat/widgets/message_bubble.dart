import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../profile/widgets/public_profile_name.dart';
import '../event_chat_models.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
  });

  final EventMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: isMine ? AppColors.primary : AppColors.border,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.sm),
              bottomRight: Radius.circular(isMine ? AppRadius.sm : AppRadius.lg),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: isMine ? 0.08 : 0.05),
                blurRadius: isMine ? 16 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine) ...[
                  PublicProfileName(
                    userId: message.senderId,
                    showUsernameTag: false,
                    compact: true,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  message.message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    _formatTime(message.createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: isMine ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
