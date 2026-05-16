import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import 'feed_models.dart';
import 'feed_provider.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _captionController = TextEditingController();
  final _eventIdController = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _imageBytes;
  String? _fileName;
  String? _contentType;

  @override
  void dispose() {
    _captionController.dispose();
    _eventIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _fileName = image.name;
      _contentType = image.mimeType;
    });
  }

  Future<void> _createPost() async {
    final bytes = _imageBytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a photo before posting.')),
      );
      return;
    }

    final post = await ref.read(feedControllerProvider.notifier).createPost(
          CreatePostInput(
            imageBytes: bytes,
            fileName: fileName,
            contentType: _contentType,
            caption: _captionController.text,
            eventId: _eventIdController.text,
          ),
        );

    if (!mounted) return;
    if (post != null) {
      context.goNamed(RouteNames.feed);
      return;
    }

    final message = ref.read(feedControllerProvider).message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const AppLogo(size: 32, showText: true)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Share a moment', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Post a photo from your day, match, or activity.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ImagePickerPreview(
              imageBytes: _imageBytes,
              onPickImage: _pickImage,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Caption',
              controller: _captionController,
              prefixIcon: const Icon(Icons.short_text),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Linked event (optional)',
              hintText: 'Leave empty for a standalone photo',
              controller: _eventIdController,
              prefixIcon: const Icon(Icons.event_outlined),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Post photo',
              isLoading: feedState.isCreating,
              onPressed: _createPost,
            ),
            if (feedState.message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                feedState.message!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.imageBytes,
    required this.onPickImage,
  });

  final Uint8List? imageBytes;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;

    return InkWell(
      borderRadius: AppRadius.xlBorder,
      onTap: onPickImage,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgBorder,
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.lgBorder,
            child: bytes == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Fotoğraf seç', style: AppTextStyles.bodyStrong),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Bir anını paylaşmak için galerinden fotoğraf seç.',
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
