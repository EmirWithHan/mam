import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Trust Score'),
      ),
      body: SafeArea(child: _TrustScoreHistoryBody(state: state)),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.profile);
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
        title: 'Henüz değişiklik yok',
        message:
            'Trust score geçmişin zamanla etkinlik davranışların ve güvenlik sinyalleriyle oluşur.',
        icon: Icons.verified_user_outlined,
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
          Text(
            'Trust score geçmişin zamanla etkinlik davranışların ve güvenlik sinyalleriyle oluşur.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppRadius.lgBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Daha güvenilir etkinlik davranışları daha güçlü sosyal sinyaller oluşturur.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
