import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import 'feed_models.dart';
import 'feed_provider.dart';
import 'widgets/linked_event_picker.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _imageBytes;
  String? _fileName;
  String? _contentType;
  String? _selectedEventId;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
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
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf seçilemedi. Galeri iznini kontrol et.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf seçilemedi. Tekrar dene.')),
      );
    }
  }

  Future<void> _createPost() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bytes = _imageBytes;
    final fileName = _fileName;
    if (bytes == null || fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paylaşmadan önce bir fotoğraf seç.')),
      );
      return;
    }

    final post = await ref
        .read(feedControllerProvider.notifier)
        .createPost(
          CreatePostInput(
            imageBytes: bytes,
            fileName: fileName,
            contentType: _contentType,
            caption: _captionController.text.trim(),
            eventId: _selectedEventId,
          ),
        );

    if (!mounted) return;
    if (post != null) {
      context.goNamed(RouteNames.home);
      return;
    }

    final message = ref.read(feedControllerProvider).message;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppResponsive.pagePadding(context),
            children: [
              Text('Bir an paylaş', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gününden, maçtan veya etkinlikten bir fotoğraf paylaş.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ImagePickerPreview(
                imageBytes: _imageBytes,
                onPickImage: feedState.isCreating ? null : _pickImage,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Açıklama',
                controller: _captionController,
                prefixIcon: const Icon(Icons.short_text),
                maxLines: 3,
                validator: Validators.postCaption,
              ),
              const SizedBox(height: AppSpacing.md),
              LinkedEventPicker(
                selectedEventId: _selectedEventId,
                onChanged: (eventId) {
                  if (feedState.isCreating) return;
                  setState(() => _selectedEventId = eventId);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'İstersen bu paylaşımı katıldığın bir etkinlikle ilişkilendirebilirsin.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Fotoğraf paylaş',
                isLoading: feedState.isCreating,
                onPressed: feedState.isCreating ? null : _createPost,
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
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.create);
  }
}

class _ImagePickerPreview extends StatelessWidget {
  const _ImagePickerPreview({
    required this.imageBytes,
    required this.onPickImage,
  });

  final Uint8List? imageBytes;
  final VoidCallback? onPickImage;

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
