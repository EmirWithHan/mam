import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/error_view.dart';
import '../feedback/feedback_models.dart';
import '../feedback/feedback_provider.dart';
import 'business_models.dart';
import 'business_provider.dart';
import 'business_service.dart';

class AdminBusinessApplicationsPage extends ConsumerStatefulWidget {
  const AdminBusinessApplicationsPage({super.key});

  @override
  ConsumerState<AdminBusinessApplicationsPage> createState() =>
      _AdminBusinessApplicationsPageState();
}

class _AdminBusinessApplicationsPageState
    extends ConsumerState<AdminBusinessApplicationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(myBusinessAccountProvider.notifier)
          .loadMyBusinessAccount();
      if (!mounted || !ref.read(myBusinessAccountProvider).isAdmin) return;

      await Future.wait([
        ref.read(pendingBusinessApplicationsProvider.notifier).loadInitial(),
        ref.read(adminFeedbackProvider.notifier).load(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final businessState = ref.watch(myBusinessAccountProvider);
    final applicationsState = ref.watch(pendingBusinessApplicationsProvider);

    return Scaffold(
      appBar: AppBar(title: const AppLogo(size: 32, showText: true)),
      body: SafeArea(
        child:
            businessState.isLoading ||
                businessState.status == BusinessAccountStatusState.initial
            ? const AppLoader()
            : businessState.isAdmin
            ? DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Başvurular'),
                        Tab(text: 'Feedback'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _AdminApplicationsBody(state: applicationsState),
                          const _AdminFeedbackBody(),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : const ErrorView(message: 'Bu alan icin admin yetkisi gerekli.'),
      ),
    );
  }
}

class _AdminFeedbackBody extends ConsumerWidget {
  const _AdminFeedbackBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminFeedbackProvider);

    if (state.isLoading && state.feedback.isEmpty) {
      return const AppLoader();
    }

    if (state.message != null && state.feedback.isEmpty) {
      return const ErrorView(message: 'Geri bildirimler yüklenemedi.');
    }

    if (state.feedback.isEmpty) {
      return const Center(child: Text('Henüz geri bildirim yok.'));
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(adminFeedbackProvider.notifier).load(force: true),
      child: ListView.separated(
        padding: AppResponsive.pagePadding(context),
        itemCount: state.feedback.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return _FeedbackReviewCard(feedback: state.feedback[index]);
        },
      ),
    );
  }
}

class _FeedbackReviewCard extends StatelessWidget {
  const _FeedbackReviewCard({required this.feedback});

  final UserFeedback feedback;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text('User: ${feedback.userId}', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              feedback.createdAt.toLocal().toString().split('.').first,
              style: AppTextStyles.caption,
            ),
            if (feedback.source != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Source: ${feedback.source}', style: AppTextStyles.caption),
            ],
            if (feedback.message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(feedback.message!, style: AppTextStyles.body),
            ],
          ],
        ),
      ),
    );
  }

  String get _title {
    final rating = feedback.rating == null
        ? 'Puan yok'
        : '${feedback.rating}/5';
    final category = feedback.category ?? 'Kategori yok';
    return '$rating · $category';
  }
}

class _AdminApplicationsBody extends ConsumerWidget {
  const _AdminApplicationsBody({required this.state});

  final PendingBusinessApplicationsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.applications.isEmpty) {
      return const AppLoader();
    }

    if (state.message != null && state.applications.isEmpty) {
      return const ErrorView(message: 'Basvurular yuklenemedi.');
    }

    if (state.applications.isEmpty) {
      return const Center(child: Text('Bekleyen isletme basvurusu yok.'));
    }

    return ListView.separated(
      padding: AppResponsive.pagePadding(context),
      itemCount: state.applications.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == state.applications.length) {
          if (!state.hasMore) {
            return Text(
              'Daha fazla içerik yok.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            );
          }
          return AppButton(
            label: 'Daha fazla yükle',
            isLoading: state.isLoadingMore,
            onPressed: state.isLoadingMore
                ? null
                : () => ref
                      .read(pendingBusinessApplicationsProvider.notifier)
                      .loadMore(),
          );
        }

        return _ApplicationReviewCard(application: state.applications[index]);
      },
    );
  }
}

class _ApplicationReviewCard extends ConsumerStatefulWidget {
  const _ApplicationReviewCard({required this.application});

  final BusinessApplication application;

  @override
  ConsumerState<_ApplicationReviewCard> createState() =>
      _ApplicationReviewCardState();
}

class _ApplicationReviewCardState
    extends ConsumerState<_ApplicationReviewCard> {
  final _noteController = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final canReview = BusinessApplicationReviewRules.canReview(
      application: application,
      isLoading: _loading,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(application.businessName, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xs),
            Text(application.businessPhone, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(application.fullAddress, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              application.category == null
                  ? 'Kategori eksik'
                  : application.customCategory ?? application.category!,
              style: AppTextStyles.bodySmall,
            ),
            if (application.website != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(application.website!, style: AppTextStyles.bodySmall),
            ],
            if (application.description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(application.description!, style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Admin notu'),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackActions = constraints.maxWidth < 340;
                final approveButton = AppButton(
                  label: 'Onayla',
                  isLoading: _loading,
                  onPressed: canReview ? () => _review(approved: true) : null,
                  fullWidth: true,
                );
                final rejectButton = AppButton(
                  label: 'Reddet',
                  isLoading: _loading,
                  variant: AppButtonVariant.outlined,
                  onPressed: canReview ? () => _review(approved: false) : null,
                  fullWidth: true,
                );

                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      approveButton,
                      const SizedBox(height: AppSpacing.sm),
                      rejectButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: approveButton),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: rejectButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review({required bool approved}) async {
    if (!BusinessApplicationReviewRules.canReview(
      application: widget.application,
      isLoading: _loading,
    )) {
      return;
    }
    setState(() => _loading = true);
    final service = ref.read(businessAccountServiceProvider);
    try {
      if (approved) {
        await service.approveApplication(
          applicationId: widget.application.id,
          adminNote: _noteController.text.trim(),
        );
      } else {
        await service.rejectApplication(
          applicationId: widget.application.id,
          adminNote: _noteController.text.trim(),
        );
      }
      ref.read(pendingBusinessApplicationsProvider.notifier).refresh();
    } on BusinessAccountException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
