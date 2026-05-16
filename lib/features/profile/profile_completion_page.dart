import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  String? _tag;

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
    _tag = profile.tag;
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
