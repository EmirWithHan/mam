import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'trust_score_provider.dart';
import 'widgets/trust_score_log_tile.dart';

class TrustScoreHistoryPage extends ConsumerStatefulWidget {
  const TrustScoreHistoryPage({super.key});

  @override
  ConsumerState<TrustScoreHistoryPage> createState() =>
      _TrustScoreHistoryPageState();
}

class _TrustScoreHistoryPageState extends ConsumerState<TrustScoreHistoryPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(trustScoreControllerProvider.notifier).loadTrustScoreLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trustScoreControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trust score history')),
      body: SafeArea(
        child: _TrustScoreHistoryBody(state: state),
      ),
    );
  }
}

class _TrustScoreHistoryBody extends ConsumerWidget {
  const _TrustScoreHistoryBody({required this.state});

  final TrustScoreState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.message != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            state.message!,
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.logs.isEmpty) {
      return Center(
        child: Text(
          'No trust score changes yet.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(trustScoreControllerProvider.notifier).refreshLogs();
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.logs.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return TrustScoreLogTile(log: state.logs[index]);
        },
      ),
    );
  }
}
