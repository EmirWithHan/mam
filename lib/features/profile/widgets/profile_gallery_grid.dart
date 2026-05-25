import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../profile_activity_models.dart';
import 'profile_gallery_viewer_page.dart';

class ProfileGalleryGrid extends StatelessWidget {
  const ProfileGalleryGrid({super.key, required this.posts});

  final List<ProfileGalleryPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(),
          SizedBox(height: AppSpacing.md),
          EmptyState(
            title: 'Henüz paylaşım yok',
            message: 'Paylaştığın fotoğraflar burada görünecek.',
            icon: Icons.photo_library_outlined,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                return _GalleryTile(post: posts[index], posts: posts);
              },
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) {
    return Text('Galeri', style: AppTextStyles.title);
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({required this.post, required this.posts});

  final ProfileGalleryPost post;
  final List<ProfileGalleryPost> posts;

  @override
  Widget build(BuildContext context) {
    final caption = post.caption?.trim();

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.lgBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openGalleryViewer(context),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _GalleryImage(imageUrl: post.imageUrl, fit: BoxFit.cover),
              if (post.eventId != null)
                const Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: _EventMarker(),
                ),
              if (post.isArchived)
                const Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: _ArchiveMarker(),
                ),
              if (caption != null && caption.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.textPrimary.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.xl,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.surface,
                        ),
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

  void _openGalleryViewer(BuildContext context) {
    context.pushNamed(
      RouteNames.profileGalleryViewer,
      extra: ProfileGalleryViewerArgs(
        initialItemId: post.id,
        items: posts
            .map(
              (item) => ProfileGalleryViewerItem(
                id: item.id,
                imageUrl: item.imageUrl,
                caption: item.caption,
                commentsHidden: item.commentsHidden,
                isArchived: item.isArchived,
                isOwner: true,
                createdAt: item.createdAt,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ArchiveMarker extends StatelessWidget {
  const _ArchiveMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.textPrimary.withValues(alpha: 0.74),
        borderRadius: AppRadius.pillBorder,
      ),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.xs),
        child: Icon(Icons.lock_outline, color: AppColors.surface, size: 16),
      ),
    );
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({required this.imageUrl, required this.fit});

  final String imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl.trim();
    if (source.isEmpty) return const _ImageErrorPlaceholder();

    return Image.network(
      source,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return const _ImageErrorPlaceholder();
      },
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.border,
      child: Center(
        child: Icon(Icons.image_not_supported, color: AppColors.textMuted),
      ),
    );
  }
}

class _EventMarker extends StatelessWidget {
  const _EventMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(
          Icons.event_available_outlined,
          color: AppColors.surface,
          size: 16,
        ),
      ),
    );
  }
}
