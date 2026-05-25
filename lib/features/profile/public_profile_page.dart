import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/error_messages.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/sport_icon.dart';
import '../auth/auth_provider.dart';
import '../follow/follow_provider.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'widgets/profile_gallery_viewer_page.dart';

enum _PublicProfileTab { gallery, events }

class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  var _selectedTab = _PublicProfileTab.gallery;

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
              context.goNamed(RouteNames.events);
            },
            icon: const Icon(Icons.arrow_back),
          ),
          title: const AppLogo(size: 32, showText: true),
        ),
        body: const SafeArea(
          child: EmptyState(
            title: 'Kullanıcı bulunamadı.',
            message: 'Bu profil bağlantısı geçerli değil.',
            icon: Icons.person_off_outlined,
          ),
        ),
      );
    }

    final detailAsync = ref.watch(publicProfileDetailProvider(widget.userId));
    final currentUserId = ref.watch(authControllerProvider).userId;

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
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(
            message: 'Profil yüklenemedi.',
            onRetry: () =>
                ref.invalidate(publicProfileDetailProvider(widget.userId)),
          ),
          data: (detail) {
            if (detail == null) {
              return const EmptyState(
                title: 'Kullanıcı bulunamadı.',
                message: 'Bu kullanıcı profili şu anda görüntülenemiyor.',
                icon: Icons.person_off_outlined,
              );
            }

            final isMe =
                currentUserId != null && currentUserId == detail.userId;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(publicProfileDetailProvider(widget.userId));
                ref.invalidate(publicProfileGalleryProvider(widget.userId));
                ref.invalidate(
                  publicProfileEventHistoryProvider(widget.userId),
                );
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _PublicProfileHeader(
                    detail: detail,
                    isMe: isMe,
                    onFollowChanged: _refreshPublicProfile,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ProfileTabs(
                    selectedTab: _selectedTab,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!detail.canViewExtendedProfile)
                    const _LockedExtendedProfileCard(),
                  if (detail.canViewExtendedProfile &&
                      _selectedTab == _PublicProfileTab.gallery)
                    _GallerySection(userId: widget.userId),
                  if (detail.canViewExtendedProfile &&
                      _selectedTab == _PublicProfileTab.events)
                    _PastEventsSection(userId: widget.userId),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _refreshPublicProfile() {
    ref.invalidate(publicProfileDetailProvider(widget.userId));
    ref.invalidate(publicProfileGalleryProvider(widget.userId));
    ref.invalidate(publicProfileEventHistoryProvider(widget.userId));
  }
}

class _PublicProfileHeader extends StatelessWidget {
  const _PublicProfileHeader({
    required this.detail,
    required this.isMe,
    required this.onFollowChanged,
  });

  final PublicProfileDetail detail;
  final bool isMe;
  final VoidCallback onFollowChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.xlBorder,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _ProfileAvatar(detail: detail),
            const SizedBox(height: AppSpacing.md),
            Text(
              detail.displayName,
              style: AppTextStyles.headline,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (detail.handleLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.handleLabel!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (detail.locationLabel != null)
                  _InfoPill(
                    icon: Icons.place_outlined,
                    label: detail.locationLabel!,
                  ),
                if (detail.trustScore != null)
                  _InfoPill(
                    icon: Icons.verified_user_outlined,
                    label: 'Güven ${detail.trustScore}',
                  ),
                if (detail.isPrivate)
                  const _InfoPill(
                    icon: Icons.lock_outline,
                    label: 'Gizli hesap',
                  ),
              ],
            ),
            if (detail.hasBio) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                detail.bio!.trim(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _ProfileStats(detail: detail),
            const SizedBox(height: AppSpacing.lg),
            _PublicProfileFollowAction(
              targetUserId: detail.userId,
              isMe: isMe,
              onChanged: onFollowChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.detail});

  final PublicProfileDetail detail;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = detail.avatarUrl?.trim();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
      ),
      child: CircleAvatar(
        radius: 48,
        backgroundColor: AppColors.surface,
        backgroundImage: avatarUrl == null || avatarUrl.isEmpty
            ? null
            : NetworkImage(avatarUrl),
        child: avatarUrl == null || avatarUrl.isEmpty
            ? Text(
                _initials(detail),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
              )
            : null,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({required this.detail});

  final PublicProfileDetail detail;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatCardData(
        value: detail.followingCount,
        label: 'Takip Edilen',
        icon: Icons.person_add_alt_1_outlined,
        onTap: () => context.pushNamed(
          RouteNames.profileFollowList,
          pathParameters: {'userId': detail.userId, 'type': 'following'},
        ),
      ),
      _StatCardData(
        value: detail.followersCount,
        label: 'Takipçi',
        icon: Icons.groups_2_outlined,
        onTap: () => context.pushNamed(
          RouteNames.profileFollowList,
          pathParameters: {'userId': detail.userId, 'type': 'followers'},
        ),
      ),
      if (detail.trustScore != null)
        _StatCardData(
          value: detail.trustScore!,
          label: 'Güven',
          icon: Icons.verified_outlined,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 420
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : (constraints.maxWidth - (AppSpacing.sm * 2)) / 3;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cardWidth.clamp(132.0, 220.0),
                child: _StatCard(data: stat),
              ),
          ],
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });

  final int value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: data.onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, color: AppColors.primary, size: 20),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _compactCount(data.value),
                  style: AppTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  data.label,
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicProfileFollowAction extends ConsumerStatefulWidget {
  const _PublicProfileFollowAction({
    required this.targetUserId,
    required this.isMe,
    required this.onChanged,
  });

  final String targetUserId;
  final bool isMe;
  final VoidCallback onChanged;

  @override
  ConsumerState<_PublicProfileFollowAction> createState() =>
      _PublicProfileFollowActionState();
}

class _PublicProfileFollowActionState
    extends ConsumerState<_PublicProfileFollowAction> {
  @override
  void initState() {
    super.initState();
    if (!widget.isMe) {
      Future.microtask(() {
        ref
            .read(followControllerProvider(widget.targetUserId).notifier)
            .loadStats();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PublicProfileFollowAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMe) return;
    if (oldWidget.targetUserId == widget.targetUserId &&
        oldWidget.isMe == widget.isMe) {
      return;
    }

    Future.microtask(() {
      ref
          .read(followControllerProvider(widget.targetUserId).notifier)
          .loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMe) {
      return AppButton(label: 'Senin profilin', onPressed: null);
    }

    final followState = ref.watch(
      followControllerProvider(widget.targetUserId),
    );
    final stats = followState.stats;
    final isFollowing = stats?.isFollowedByMe ?? false;
    final requestPending = stats?.hasPendingRequestByMe ?? false;

    return AppButton(
      label: isFollowing
          ? 'Takip Ediliyor'
          : requestPending
          ? 'İstek Gönderildi'
          : 'Takip Et',
      variant: isFollowing || requestPending
          ? AppButtonVariant.secondary
          : AppButtonVariant.primary,
      isLoading: followState.loading || stats == null,
      onPressed: followState.loading || stats == null ? null : _toggleFollow,
    );
  }

  Future<void> _toggleFollow() async {
    final controller = ref.read(
      followControllerProvider(widget.targetUserId).notifier,
    );

    await controller.toggleFollow();
    if (!mounted) return;

    final message = ref
        .read(followControllerProvider(widget.targetUserId))
        .message;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(message))));
      return;
    }

    widget.onChanged();
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selectedTab, required this.onChanged});

  final _PublicProfileTab selectedTab;
  final ValueChanged<_PublicProfileTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            _TabButton(
              label: 'Galeri',
              icon: Icons.grid_view_rounded,
              selected: selectedTab == _PublicProfileTab.gallery,
              onPressed: () => onChanged(_PublicProfileTab.gallery),
            ),
            _TabButton(
              label: 'Geçmiş Events',
              icon: Icons.event_available_outlined,
              selected: selectedTab == _PublicProfileTab.events,
              onPressed: () => onChanged(_PublicProfileTab.events),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.transparent,
          foregroundColor: selected ? Colors.white : AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _GallerySection extends ConsumerWidget {
  const _GallerySection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(publicProfileGalleryProvider(userId));
    final currentUserId = ref.watch(authControllerProvider).userId;
    final isOwner = currentUserId != null && currentUserId == userId;
    return galleryAsync.when(
      loading: () => const _SectionLoader(),
      error: (error, _) => _SectionError(
        message: 'Galeri yüklenemedi.',
        onRetry: () => ref.invalidate(publicProfileGalleryProvider(userId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            title: 'Henüz galeri paylaşımı yok.',
            message: 'Fotoğraf paylaşımları burada görünecek.',
            icon: Icons.photo_library_outlined,
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              borderRadius: AppRadius.mdBorder,
              onTap: () => _openGalleryViewer(context, items, item, isOwner),
              child: ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const ColoredBox(
                          color: AppColors.border,
                          child: Icon(Icons.image_not_supported_outlined),
                        );
                      },
                    ),
                    if (item.isArchived)
                      Positioned(
                        top: AppSpacing.xs,
                        right: AppSpacing.xs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.textPrimary.withValues(
                              alpha: 0.74,
                            ),
                            borderRadius: AppRadius.pillBorder,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(AppSpacing.xs),
                            child: Icon(
                              Icons.lock_outline,
                              color: AppColors.surface,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openGalleryViewer(
    BuildContext context,
    List<PublicProfileGalleryItem> items,
    PublicProfileGalleryItem item,
    bool isOwner,
  ) {
    context.pushNamed(
      RouteNames.profileGalleryViewer,
      extra: ProfileGalleryViewerArgs(
        initialItemId: item.postId,
        items: items
            .map(
              (entry) => ProfileGalleryViewerItem(
                id: entry.postId,
                imageUrl: entry.imageUrl,
                caption: entry.caption,
                commentsHidden: entry.commentsHidden,
                isArchived: entry.isArchived,
                isOwner: isOwner,
                createdAt: entry.createdAt,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PastEventsSection extends ConsumerWidget {
  const _PastEventsSection({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(publicProfileEventHistoryProvider(userId));
    return eventsAsync.when(
      loading: () => const _SectionLoader(),
      error: (error, _) => _SectionError(
        message: 'Geçmiş etkinlikler yüklenemedi.',
        onRetry: () =>
            ref.invalidate(publicProfileEventHistoryProvider(userId)),
      ),
      data: (events) {
        final activeEvents = events.where((event) => !event.isPast).toList();
        final pastEvents = events.where((event) => event.isPast).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aktif Events', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            _PublicEventSectionList(
              events: activeEvents,
              emptyTitle: 'Aktif etkinlik yok.',
              emptyMessage:
                  'Yaklaşan veya devam eden etkinlikler burada görünür.',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Geçmiş Events', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.md),
            _PublicEventSectionList(
              events: pastEvents,
              emptyTitle: 'Geçmiş event yok.',
              emptyMessage: 'Tamamlanan etkinlikler burada görünür.',
            ),
          ],
        );
      },
    );
  }
}

class _PublicEventSectionList extends StatelessWidget {
  const _PublicEventSectionList({
    required this.events,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<PublicProfileEventHistoryItem> events;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.event_available_outlined,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return _PastEventTile(item: events[index]);
      },
    );
  }
}

class _PastEventTile extends StatelessWidget {
  const _PastEventTile({required this.item});

  final PublicProfileEventHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: () => context.pushNamed(
          RouteNames.eventDetail,
          pathParameters: {'eventId': item.eventId},
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SportIcon(sportType: item.sportType, size: 22),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTextStyles.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${item.sportType} • ${item.locationLabel}',
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        DateFormatter.shortDate(item.eventDate),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _RoleBadge(role: item.role),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final label = role == 'host' ? 'Host' : 'Katılımcı';

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
          label,
          style: AppTextStyles.label.copyWith(color: AppColors.primary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SectionLoader extends StatelessWidget {
  const _SectionLoader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(child: AppLoader()),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Tekrar dene',
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedExtendedProfileCard extends StatelessWidget {
  const _LockedExtendedProfileCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Bu alanı görmek için kullanıcıyı takip etmelisin.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(PublicProfileDetail detail) {
  final parts = [
    detail.firstName?.trim(),
    detail.lastName?.trim(),
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

  if (parts.isNotEmpty) {
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  final username = detail.username?.trim();
  if (username != null && username.isNotEmpty) {
    return username[0].toUpperCase();
  }

  return 'M';
}

String _compactCount(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final count = value / 1000;
    return '${count.toStringAsFixed(count >= 10 ? 0 : 1)}K';
  }
  final count = value / 1000000;
  return '${count.toStringAsFixed(count >= 10 ? 0 : 1)}M';
}
