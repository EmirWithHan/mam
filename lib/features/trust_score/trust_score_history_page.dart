import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
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
      appBar: AppBar(title: const Text('MaM')),
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
      return const AppLoader();
    }

    if (state.message != null) {
      return ErrorView(message: state.message!);
    }

    if (state.logs.isEmpty) {
      return const EmptyState(
        title: 'No trust score changes yet.',
        message: 'Reliable event behavior will appear here over time.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(trustScoreControllerProvider.notifier).refreshLogs();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Trust Score', style: AppTextStyles.headline),
          const SizedBox(height: AppSpacing.sm),
          Text('Your reliability history across events.', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          ...state.logs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TrustScoreLogTile(log: log),
            ),
          ),
        ],
      ),
    );
  }
}
