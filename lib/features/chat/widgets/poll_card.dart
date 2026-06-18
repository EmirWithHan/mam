import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/supabase_service.dart';
import '../event_chat_provider.dart';

class PollCard extends ConsumerStatefulWidget {
  const PollCard({super.key, required this.pollId, required this.eventId});

  final String pollId;
  final String eventId;

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  bool _loading = true;
  String? _question;
  List<Map<String, dynamic>> _options = [];
  List<Map<String, dynamic>> _votes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPoll();
  }

  Future<void> _loadPoll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(eventChatServiceProvider);
      final details = await service.fetchPollDetails(widget.pollId);

      if (mounted) {
        setState(() {
          _question = details['question']?.toString() ?? 'Anket';
          _options = List<Map<String, dynamic>>.from(
            details['chat_poll_options'] as List? ?? [],
          );
          _votes = List<Map<String, dynamic>>.from(
            details['chat_poll_votes'] as List? ?? [],
          );
          _loading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Anket yüklenemedi';
          _loading = false;
        });
      }
    }
  }

  Future<void> _vote(String optionId) async {
    final controller = ref.read(
      eventChatControllerProvider(widget.eventId).notifier,
    );
    await controller.castVote(pollId: widget.pollId, optionId: optionId);
    _loadPoll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        color: AppColors.surfaceSoft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(_error!, style: const TextStyle(color: AppColors.error)),
        ),
      );
    }

    final currentUserId = SupabaseService.client.auth.currentUser?.id;
    final totalVotes = _votes.length;

    final userVote = _votes.firstWhere(
      (v) => v['user_id']?.toString() == currentUserId,
      orElse: () => {},
    );
    final userVotedOptionId = userVote['option_id']?.toString();

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBorder,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.poll_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Anket',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_question ?? '', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.md),
            ..._options.map((opt) {
              final optionId = opt['id'].toString();
              final optionText = opt['option_text'].toString();

              final optionVotes = _votes
                  .where((v) => v['option_id'].toString() == optionId)
                  .length;
              final percentage = totalVotes > 0
                  ? optionVotes / totalVotes
                  : 0.0;
              final isMyVote = userVotedOptionId == optionId;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => _vote(optionId),
                  borderRadius: AppRadius.mdBorder,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isMyVote ? AppColors.primary : AppColors.border,
                        width: isMyVote ? 1.5 : 1.0,
                      ),
                      borderRadius: AppRadius.mdBorder,
                      color: isMyVote
                          ? AppColors.primarySoft.withValues(alpha: 0.1)
                          : Colors.transparent,
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                optionText,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: isMyVote ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                            Text(
                              '$optionVotes oy (${(percentage * 100).round()}%)',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: isMyVote ? FontWeight.bold : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isMyVote
                                  ? AppColors.primary
                                  : AppColors.secondary,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Toplam $totalVotes oy',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
