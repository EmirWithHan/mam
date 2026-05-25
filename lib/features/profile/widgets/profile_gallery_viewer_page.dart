import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/empty_state.dart';
import '../profile_activity_provider.dart';
import '../profile_provider.dart';

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
    this.commentsHidden = false,
    this.isArchived = false,
    this.isOwner = false,
    required this.createdAt,
  });

  final String id;
  final String imageUrl;
  final String? caption;
  final bool commentsHidden;
  final bool isArchived;
  final bool isOwner;
  final DateTime createdAt;

  ProfileGalleryViewerItem copyWith({bool? commentsHidden, bool? isArchived}) {
    return ProfileGalleryViewerItem(
      id: id,
      imageUrl: imageUrl,
      caption: caption,
      commentsHidden: commentsHidden ?? this.commentsHidden,
      isArchived: isArchived ?? this.isArchived,
      isOwner: isOwner,
      createdAt: createdAt,
    );
  }
}

class ProfileGalleryViewerPage extends ConsumerStatefulWidget {
  const ProfileGalleryViewerPage({super.key, required this.args});

  final ProfileGalleryViewerArgs? args;

  @override
  ConsumerState<ProfileGalleryViewerPage> createState() =>
      _ProfileGalleryViewerPageState();
}

class _ProfileGalleryViewerPageState
    extends ConsumerState<ProfileGalleryViewerPage> {
  late final PageController _pageController;
  late List<ProfileGalleryViewerItem> _items;
  var _currentIndex = 0;
  var _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _items = [...?widget.args?.items];
    _currentIndex = _initialIndex();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final currentItem = items.isEmpty
        ? null
        : items[_currentIndex.clamp(0, items.length - 1)];

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
        actions: [
          if (currentItem?.isOwner == true)
            IconButton(
              tooltip: 'İşlemler',
              onPressed: _isUpdating || currentItem == null
                  ? null
                  : () => _showOwnerMenu(currentItem),
              icon: const Icon(Icons.more_horiz),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
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
                onPageChanged: (index) => setState(() => _currentIndex = index),
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
    final index = args.items.indexWhere(
      (item) => item.id == args.initialItemId,
    );
    return index < 0 ? 0 : index;
  }

  Future<void> _showOwnerMenu(ProfileGalleryViewerItem item) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GalleryMenuItem(
                  icon: Icons.mode_comment_outlined,
                  label: item.commentsHidden
                      ? 'Yorumları göster'
                      : 'Yorumları gizle',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateItem(item, commentsHidden: !item.commentsHidden);
                  },
                ),
                _GalleryMenuItem(
                  icon: item.isArchived
                      ? Icons.lock_open_outlined
                      : Icons.archive_outlined,
                  label: item.isArchived ? 'Arşivden çıkar' : 'Arşivle',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _updateItem(item, isArchived: !item.isArchived);
                  },
                ),
                _GalleryMenuItem(
                  icon: Icons.delete_outline,
                  label: 'Sil',
                  destructive: true,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmDelete(item);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateItem(
    ProfileGalleryViewerItem item, {
    bool? commentsHidden,
    bool? isArchived,
  }) async {
    setState(() => _isUpdating = true);
    try {
      await ref
          .read(profileServiceProvider)
          .updateGalleryPostControls(
            postId: item.id,
            commentsHidden: commentsHidden,
            isArchived: isArchived,
          );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final entry in _items)
            if (entry.id == item.id)
              entry.copyWith(
                commentsHidden: commentsHidden,
                isArchived: isArchived,
              )
            else
              entry,
        ];
        _isUpdating = false;
      });
      ref.read(profileActivityControllerProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı.')));
    }
  }

  Future<void> _confirmDelete(ProfileGalleryViewerItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Bu gönderiyi silmek istediğine emin misin?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await ref.read(profileServiceProvider).deleteMyGalleryPost(item.id);
      ref.read(profileActivityControllerProvider.notifier).refresh();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(RouteNames.profile);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gönderi silinemedi.')));
    }
  }
}

class _GalleryMenuItem extends StatelessWidget {
  const _GalleryMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textSecondary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: AppTextStyles.bodyStrong.copyWith(color: color),
      ),
      onTap: onTap,
    );
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
