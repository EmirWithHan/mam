import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/empty_state.dart';

class ProfileGalleryViewerArgs {
  const ProfileGalleryViewerArgs({
    required this.items,
    required this.initialItemId,
  });

  final List<ProfileGalleryViewerItem> items;
  final String initialItemId;
}

class ProfileGalleryViewerItem {
  const ProfileGalleryViewerItem({
    required this.id,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
}

class ProfileGalleryViewerPage extends StatefulWidget {
  const ProfileGalleryViewerPage({
    super.key,
    required this.args,
  });

  final ProfileGalleryViewerArgs? args;

  @override
  State<ProfileGalleryViewerPage> createState() =>
      _ProfileGalleryViewerPageState();
}

class _ProfileGalleryViewerPageState extends State<ProfileGalleryViewerPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialIndex());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.args?.items ?? const <ProfileGalleryViewerItem>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const EmptyState(
                title: 'Galeri boş.',
                message: 'Gösterilecek fotoğraf bulunamadı.',
                icon: Icons.photo_library_outlined,
              )
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _GalleryViewerPost(item: items[index]);
                },
              ),
      ),
    );
  }

  int _initialIndex() {
    final args = widget.args;
    if (args == null || args.items.isEmpty) return 0;
    final index = args.items.indexWhere((item) => item.id == args.initialItemId);
    return index < 0 ? 0 : index;
  }
}

class _GalleryViewerPost extends StatelessWidget {
  const _GalleryViewerPost({required this.item});

  final ProfileGalleryViewerItem item;

  @override
  Widget build(BuildContext context) {
    final caption = item.caption?.trim();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Galeri', style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.md),
        DecoratedBox(
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.lgBorder,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _ViewerImage(imageUrl: item.imageUrl),
                  ),
                ),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(caption, style: AppTextStyles.body),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(_formatDate(item.createdAt), style: AppTextStyles.caption),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day.$month.$year';
  }
}

class _ViewerImage extends StatelessWidget {
  const _ViewerImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final source = imageUrl.trim();
    if (source.isEmpty) return const _ImagePlaceholder();

    return ColoredBox(
      color: AppColors.textPrimary,
      child: Image.network(
        source,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const _ImagePlaceholder();
        },
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

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
