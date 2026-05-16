import 'dart:math';
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
import '../../core/widgets/app_text_field.dart';
import 'profile_models.dart';
import 'profile_provider.dart';

class ProfileCompletionPage extends ConsumerStatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  ConsumerState<ProfileCompletionPage> createState() =>
      _ProfileCompletionPageState();
}

class _ProfileCompletionPageState
    extends ConsumerState<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _genderController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _tag;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarContentType;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProfile);
  }

  Future<void> _loadProfile() async {
    final profile = await ref
        .read(profileControllerProvider.notifier)
        .createEmptyProfileIfMissing();
    if (!mounted || profile == null) return;

    _usernameController.text = profile.username ?? '';
    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';
    _birthDateController.text = _formatDate(profile.birthDate);
    _genderController.text = profile.gender ?? '';
    _cityController.text = profile.city ?? '';
    _districtController.text = profile.district ?? '';
    _phoneController.text = profile.phone ?? '';
    _avatarUrl = profile.avatarUrl;
    _tag = profile.tag;
    setState(() {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _genderController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    var avatarUrl = _avatarUrl;
    final avatarBytes = _avatarBytes;
    final avatarFileName = _avatarFileName;
    if (avatarBytes != null && avatarFileName != null) {
      avatarUrl = await ref.read(profileControllerProvider.notifier).uploadAvatar(
            bytes: avatarBytes,
            fileName: avatarFileName,
            contentType: _avatarContentType,
          );

      if (!mounted) return;
      if (avatarUrl == null) {
        final message = ref.read(profileControllerProvider).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Avatar upload failed.')),
        );
        return;
      }
    }

    final formData = ProfileFormData(
      username: _usernameController.text,
      tag: _tag?.isNotEmpty == true ? _tag! : _generateTag(),
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      birthDate: DateTime.parse(_birthDateController.text.trim()),
      gender: _genderController.text,
      city: _cityController.text,
      district: _districtController.text,
      phone: _phoneController.text,
      avatarUrl: avatarUrl,
    );

    final profile = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(formData);

    if (!mounted) return;
    if (profile != null) {
      context.goNamed(RouteNames.home);
      return;
    }

    final message = ref.read(profileControllerProvider).message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _pickAvatar() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _avatarBytes = bytes;
      _avatarFileName = image.name;
      _avatarContentType = image.mimeType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MaM')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Profilini tamamla', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Etkinlik oluşturmak ve katılım isteği göndermek için profil bilgilerini tamamla.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormCard(
                child: Column(
                  children: [
                    _AvatarPicker(
                      imageBytes: _avatarBytes,
                      avatarUrl: _avatarUrl,
                      onPickAvatar: _pickAvatar,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Username',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.alternate_email),
                      validator: _requiredValidator('Username'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'First name',
                      controller: _firstNameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: _requiredValidator('First name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Last name',
                      controller: _lastNameController,
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: _requiredValidator('Last name'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Birth date',
                      hintText: 'YYYY-MM-DD',
                      controller: _birthDateController,
                      keyboardType: TextInputType.datetime,
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      validator: _birthDateValidator,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Gender',
                      controller: _genderController,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: _requiredValidator('Gender'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'City',
                      controller: _cityController,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      validator: _requiredValidator('City'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'District (optional)',
                      controller: _districtController,
                      prefixIcon: const Icon(Icons.place_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Phone (optional)',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save profile',
                isLoading: profileState.isLoading,
                onPressed: _submit,
              ),
              if (profileState.status == ProfileStatus.error &&
                  profileState.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  profileState.message!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$label is required.';
      }
      return null;
    };
  }

  String? _birthDateValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Birth date is required.';
    }
    if (DateTime.tryParse(value.trim()) == null) {
      return 'Use YYYY-MM-DD format.';
    }
    return null;
  }

  String _generateTag() {
    final value = Random().nextInt(10000);
    return value.toString().padLeft(4, '0');
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
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
        child: child,
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.imageBytes,
    required this.avatarUrl,
    required this.onPickAvatar,
  });

  final Uint8List? imageBytes;
  final String? avatarUrl;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final currentAvatarUrl = avatarUrl?.trim();

    return Column(
      children: [
        InkWell(
          borderRadius: AppRadius.pillBorder,
          onTap: onPickAvatar,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: imageBytes == null &&
                        currentAvatarUrl != null &&
                        currentAvatarUrl.isNotEmpty
                    ? NetworkImage(currentAvatarUrl)
                    : null,
                child: imageBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          imageBytes!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )
                    : currentAvatarUrl == null || currentAvatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 46,
                          )
                        : null,
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: onPickAvatar,
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Upload avatar'),
        ),
      ],
    );
  }
}
