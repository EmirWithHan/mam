import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/turkey_locations.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import 'business_models.dart';
import 'business_provider.dart';

class CreateBusinessAccountPage extends ConsumerStatefulWidget {
  const CreateBusinessAccountPage({super.key});

  @override
  ConsumerState<CreateBusinessAccountPage> createState() =>
      _CreateBusinessAccountPageState();
}

class _CreateBusinessAccountPageState
    extends ConsumerState<CreateBusinessAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();

  String? _category;
  String? _city;
  String? _district;
  String? _loadedAccountId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _customCategoryController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myBusinessAccountProvider);
    final account = state.account;
    if (account != null && _loadedAccountId != account.id) {
      _loadAccount(account);
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                account == null
                    ? 'Isletme Hesabi Olustur'
                    : 'Isletmeyi Duzenle',
                style: AppTextStyles.headline,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Mekanini veya isletmeni Match A Man’da ayri bir profille tanit.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Isletme adi',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      validator: BusinessAccountValidators.name,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Kullanici adi',
                      controller: _usernameController,
                      prefixIcon: const Icon(Icons.alternate_email),
                      helperText: 'Ornek: bozkiratciftligi',
                      onChanged: (value) {
                        final normalized =
                            BusinessAccountValidators.normalizeUsername(value);
                        if (normalized != value) {
                          _usernameController.value = TextEditingValue(
                            text: normalized,
                            selection: TextSelection.collapsed(
                              offset: normalized.length,
                            ),
                          );
                        }
                      },
                      validator: BusinessAccountValidators.username,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DropdownField(
                      label: 'Kategori',
                      value: _category,
                      values: BusinessCategories.values,
                      icon: Icons.category_outlined,
                      validator: BusinessAccountValidators.category,
                      onChanged: (value) {
                        setState(() {
                          _category = value;
                          if (!BusinessCategories.isOther(value)) {
                            _customCategoryController.clear();
                          }
                        });
                      },
                    ),
                    if (BusinessCategories.isOther(_category)) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'İşletme türünü yaz',
                        hintText: 'Örn. Okçuluk kulübü, kano merkezi...',
                        controller: _customCategoryController,
                        prefixIcon: const Icon(Icons.edit_outlined),
                        validator: (value) =>
                            BusinessAccountValidators.customCategory(
                          category: _category,
                          value: value,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _DropdownField(
                      label: 'Sehir',
                      value: _city,
                      values: TurkeyLocations.getCities(),
                      icon: Icons.location_city_outlined,
                      validator: (value) => BusinessAccountValidators
                          .cityDistrict(city: value, district: _district),
                      onChanged: (value) {
                        setState(() {
                          _city = value;
                          _district = null;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _DropdownField(
                      label: 'Ilce',
                      value: _district,
                      values: _city == null
                          ? const []
                          : TurkeyLocations.getDistricts(_city!),
                      icon: Icons.place_outlined,
                      validator: (value) => BusinessAccountValidators
                          .cityDistrict(city: _city, district: value),
                      onChanged: (value) => setState(() => _district = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormCard(
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Adres',
                      controller: _addressController,
                      prefixIcon: const Icon(Icons.map_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Aciklama',
                      controller: _descriptionController,
                      prefixIcon: const Icon(Icons.notes_outlined),
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Telefon',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined),
                      helperText: 'Dogrulama bu surumde yok.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Website',
                      controller: _websiteController,
                      keyboardType: TextInputType.url,
                      prefixIcon: const Icon(Icons.language_outlined),
                      validator: BusinessAccountValidators.website,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Instagram',
                      controller: _instagramController,
                      prefixIcon: const Icon(Icons.photo_camera_outlined),
                      validator: BusinessAccountValidators.instagram,
                    ),
                  ],
                ),
              ),
              if (state.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  state.message!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: account == null ? 'Isletme hesabi olustur' : 'Kaydet',
                isLoading: state.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadAccount(BusinessAccount account) {
    _loadedAccountId = account.id;
    _nameController.text = account.name;
    _usernameController.text = account.username;
    _category = account.category;
    _customCategoryController.text = account.customCategory ?? '';
    _city = account.city;
    _district = account.district;
    _addressController.text = account.address ?? '';
    _descriptionController.text = account.description ?? '';
    _phoneController.text = account.phone ?? '';
    _websiteController.text = account.website ?? '';
    _instagramController.text = account.instagram ?? '';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final input = BusinessAccountInput(
      name: _nameController.text,
      username: _usernameController.text,
      category: _category ?? '',
      customCategory: _customCategoryController.text,
      city: _city ?? '',
      district: _district ?? '',
      address: _addressController.text,
      description: _descriptionController.text,
      phone: _phoneController.text,
      website: _websiteController.text,
      instagram: _instagramController.text,
    );

    final controller = ref.read(myBusinessAccountProvider.notifier);
    final existing = ref.read(myBusinessAccountProvider).account;
    final account = existing == null
        ? await controller.createBusinessAccount(input)
        : await controller.updateBusinessAccount(id: existing.id, input: input);

    if (!mounted || account == null) return;
    context.goNamed(
      RouteNames.businessProfile,
      pathParameters: {'businessId': account.id},
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.settings);
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

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.values,
    required this.icon,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final String? value;
  final List<String> values;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = values.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      items: [
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: values.isEmpty ? null : onChanged,
      validator: validator,
    );
  }
}
