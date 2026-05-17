import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../profile_activity_models.dart';

class ProfileGalleryGrid extends StatelessWidget {
  const ProfileGalleryGrid({
    super.key,
    required this.posts,
  });

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
                return _GalleryTile(post: posts[index]);
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
  const _GalleryTile({required this.post});

  final ProfileGalleryPost post;

  @override
  Widget build(BuildContext context) {
    final caption = post.caption?.trim();

    return DecoratedBox(
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
      child: ClipRRect(
        borderRadius: AppRadius.lgBorder,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              post.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const ColoredBox(
                  color: AppColors.border,
                  child: Center(child: Icon(Icons.image_not_supported)),
                );
              },
            ),
            if (post.eventId != null)
              const Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _EventMarker(),
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
