import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/sport_icon.dart';
import '../auth/auth_provider.dart';
import '../follow/widgets/follow_button.dart';
import 'profile_models.dart';
import 'profile_provider.dart';
import 'widgets/profile_gallery_viewer_page.dart';

enum _PublicProfileTab { events, gallery }

class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  var _selectedTab = _PublicProfileTab.events;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(publicProfileDetailProvider(widget.userId));
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
            context.goNamed(RouteNames.profile);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const AppLoader(),
          error: (error, _) => ErrorView(message: '$error'),
          data: (detail) {
            if (detail == null) {
              return const EmptyState(
                title: 'Profil bulunamadı.',
                message: 'Bu kullanıcı profili şu anda görüntülenemiyor.',
                icon: Icons.person_off_outlined,
              );
            }

            final isMe =
                currentUserId != null && currentUserId == detail.userId;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _PublicProfileHeader(
                  detail: detail,
                  isMe: isMe,
                  onFollowChanged: () {
                    ref.invalidate(publicProfileDetailProvider(widget.userId));
                    ref.invalidate(publicProfileGalleryProvider(widget.userId));
                    ref.invalidate(
                      publicProfileEventHistoryProvider(widget.userId),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (detail.canViewExtendedProfile) ...[
                  _ProfileTabs(
                    selectedTab: _selectedTab,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_selectedTab == _PublicProfileTab.events)
                    _PastEventsSection(userId: widget.userId)
                  else
                    _GallerySection(userId: widget.userId),
                ] else
                  const _LockedExtendedProfileCard(),
              ],
            );
          },
        ),
      ),
    );
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
            blurRadius: 22,
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
            ),
            if (detail.handleLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.handleLabel!,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (detail.city?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail.city!,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
            if (detail.hasBio) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                detail.bio!.trim(),
                style: AppTextStyles.bodySmall.copyWith(height: 1.35),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: detail.followingCount,
                    label: 'Following',
                    onTap: () => context.pushNamed(
                      RouteNames.profileFollowList,
                      pathParameters: {
                        'userId': detail.userId,
                        'type': 'following',
                      },
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatCard(
                    value: detail.followersCount,
                    label: 'Followers',
                    onTap: () => context.pushNamed(
                      RouteNames.profileFollowList,
                      pathParameters: {
                        'userId': detail.userId,
                        'type': 'followers',
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (!isMe) ...[
              const SizedBox(height: AppSpacing.lg),
              FollowButton(
                targetUserId: detail.userId,
                fullWidth: true,
                onChanged: onFollowChanged,
              ),
            ],
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
    return CircleAvatar(
      radius: 46,
      backgroundColor: AppColors.primarySoft,
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
    );
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Text('$value', style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.xs),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ),
    );
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
              label: 'Geçmiş Etkinlikler',
              selected: selectedTab == _PublicProfileTab.events,
              onPressed: () => onChanged(_PublicProfileTab.events),
            ),
            _TabButton(
              label: 'Galeri',
              selected: selectedTab == _PublicProfileTab.gallery,
              onPressed: () => onChanged(_PublicProfileTab.gallery),
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
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.transparent,
          foregroundColor: selected ? Colors.white : AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
        ),
        onPressed: onPressed,
        child: Text(label, textAlign: TextAlign.center),
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
    return galleryAsync.when(
      loading: () => const AppLoader(),
      error: (error, _) => const _LockedExtendedProfileCard(),
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
              onTap: () => _openGalleryViewer(context, items, item),
              child: ClipRRect(
                borderRadius: AppRadius.mdBorder,
                child: Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: AppColors.border,
                      child: Icon(Icons.image_not_supported_outlined),
                    );
                  },
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
      loading: () => const AppLoader(),
      error: (error, _) => const _LockedExtendedProfileCard(),
      data: (events) {
        if (events.isEmpty) {
          return const EmptyState(
            title: 'Henüz geçmiş etkinlik yok.',
            message: 'Katıldığı veya düzenlediği etkinlikler burada görünür.',
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
      },
    );
  }
}

class _PastEventTile extends StatelessWidget {
  const _PastEventTile({required this.item});

  final PublicProfileEventHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: InkWell(
        borderRadius: AppRadius.lgBorder,
        onTap: () => context.pushNamed(
          RouteNames.eventDetail,
          pathParameters: {'eventId': item.eventId},
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              SportIcon(sportType: item.sportType, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${item.sportType} • ${item.locationLabel}',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      DateFormatter.shortDate(item.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DecoratedBox(
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
                    item.roleLabel,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                'Galeri ve geçmiş etkinlikleri görmek için kullanıcıyı takip etmelisin.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
