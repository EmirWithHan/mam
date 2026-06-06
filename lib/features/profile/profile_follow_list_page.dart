import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../auth/auth_provider.dart';
import 'profile_follow_list_provider.dart';
import 'profile_models.dart';
import 'widgets/safe_avatar.dart';

class ProfileFollowListPage extends ConsumerStatefulWidget {
  const ProfileFollowListPage({
    super.key,
    required this.userId,
    required this.type,
  });

  final String userId;
  final ProfileFollowListType type;

  @override
  ConsumerState<ProfileFollowListPage> createState() =>
      _ProfileFollowListPageState();
}

class _ProfileFollowListPageState extends ConsumerState<ProfileFollowListPage> {
  late final ScrollController _scrollController;

  ProfileFollowListArgs get _args =>
      ProfileFollowListArgs(userId: widget.userId, type: widget.type);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    if (widget.userId.trim().isEmpty) return;
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(profileFollowListControllerProvider(_args).notifier)
          .loadInitial();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileFollowListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId && oldWidget.type == widget.type) {
      return;
    }
    if (widget.userId.trim().isEmpty) return;

    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(profileFollowListControllerProvider(_args).notifier)
          .loadInitial();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.goNamed(RouteNames.profile);
            },
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.type.title),
        ),
        body: const SafeArea(
          child: EmptyState(
            title: 'Kullanıcı bulunamadı.',
            message: 'Bu liste bağlantısı geçerli değil.',
            icon: Icons.person_off_outlined,
          ),
        ),
      );
    }

    final state = ref.watch(profileFollowListControllerProvider(_args));
    final controller = ref.read(
      profileFollowListControllerProvider(_args).notifier,
    );
    final currentUserId = ref.watch(authControllerProvider).userId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.goNamed(
              RouteNames.publicProfile,
              pathParameters: {'userId': widget.userId},
            );
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.type.title),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: _ProfileFollowListBody(
            state: state,
            type: widget.type,
            currentUserId: currentUserId,
            scrollController: _scrollController,
            onRetry: controller.loadInitial,
            onToggleFollow: controller.toggleFollow,
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.extentAfter > 420) return;

    ref.read(profileFollowListControllerProvider(_args).notifier).loadMore();
  }
}

class _ProfileFollowListBody extends StatelessWidget {
  const _ProfileFollowListBody({
    required this.state,
    required this.type,
    required this.currentUserId,
    required this.scrollController,
    required this.onRetry,
    required this.onToggleFollow,
  });

  final ProfileFollowListState state;
  final ProfileFollowListType type;
  final String? currentUserId;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final ValueChanged<PublicProfileFollowListItem> onToggleFollow;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: AppLoader());
    }

    if (state.hasError && state.items.isEmpty) {
      return ErrorView(message: 'Liste yüklenemedi.', onRetry: onRetry);
    }

    if (state.items.isEmpty) {
      return ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: EmptyState(
              title: type.emptyTitle,
              icon: Icons.people_outline_rounded,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: AppLoader()),
          );
        }

        final item = state.items[index];
        return _ProfileFollowListTile(
          item: item,
          isMe: item.userId == currentUserId,
          isToggling: state.togglingUserIds.contains(item.userId),
          onToggleFollow: () => onToggleFollow(item),
        );
      },
    );
  }
}

class _ProfileFollowListTile extends StatelessWidget {
  const _ProfileFollowListTile({
    required this.item,
    required this.isMe,
    required this.isToggling,
    required this.onToggleFollow,
  });

  final PublicProfileFollowListItem item;
  final bool isMe;
  final bool isToggling;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: isMe
            ? null
            : () => context.pushNamed(
                RouteNames.publicProfile,
                pathParameters: {'userId': item.userId},
              ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FollowListAvatar(item: item),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _FollowListText(item: item)),
              if (!isMe) ...[
                const SizedBox(width: AppSpacing.sm),
                _FollowListButton(
                  isFollowing: item.isFollowingByMe,
                  requestPending: item.pendingFollowRequestByMe,
                  isLoading: isToggling,
                  onPressed: onToggleFollow,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowListAvatar extends StatelessWidget {
  const _FollowListAvatar({required this.item});

  final PublicProfileFollowListItem item;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = item.avatarUrl?.trim();
    return SafeAvatar(
      radius: 26,
      avatarUrl: avatarUrl,
      fallbackText: _initials(item),
      fontSize: 18,
    );
  }
}

class _FollowListText extends StatelessWidget {
  const _FollowListText({required this.item});

  final PublicProfileFollowListItem item;

  @override
  Widget build(BuildContext context) {
    final handle = item.displayHandle;
    final location = _locationLabel(item);
    final bio = item.bio?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.displayName,
          style: AppTextStyles.bodyStrong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (handle != null && handle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            handle,
            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (location != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            location,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            bio,
            style: AppTextStyles.bodySmall.copyWith(height: 1.25),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (item.trustScore != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _TrustBadge(score: item.trustScore!),
        ],
      ],
    );
  }
}

class _FollowListButton extends StatelessWidget {
  const _FollowListButton({
    required this.isFollowing,
    required this.requestPending,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool requestPending;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: isFollowing
          ? 'Takip Ediliyor'
          : requestPending
          ? 'İstek Gönderildi'
          : 'Takip Et',
      onPressed: onPressed,
      isLoading: isLoading,
      fullWidth: false,
      variant: isFollowing || requestPending
          ? AppButtonVariant.outlined
          : AppButtonVariant.primary,
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
          'Güven $score',
          style: AppTextStyles.label.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

String _initials(PublicProfileFollowListItem item) {
  final nameParts = item.displayName
      .split(' ')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  if (nameParts.isNotEmpty) {
    return nameParts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  return 'M';
}

String? _locationLabel(PublicProfileFollowListItem item) {
  final city = item.city?.trim();
  final district = item.district?.trim();
  if (city == null || city.isEmpty) return null;
  if (district == null || district.isEmpty) return city;
  return '$city / $district';
}
