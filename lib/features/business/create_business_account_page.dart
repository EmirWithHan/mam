import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/responsive_layout.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_text_field.dart';
import '../auth/auth_provider.dart';
import '../events/events_provider.dart';
import '../profile/profile_provider.dart';
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
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

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
    _phoneController.dispose();
    _addressController.dispose();
    _customCategoryController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myBusinessAccountProvider);
    final account = state.account;
    final application = state.application;
    final isPending = application?.isPending == true;

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
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text(
              account == null
                  ? 'İşletme hesabı başvurusu'
                  : 'İşletme hesabını düzenle',
              style: AppTextStyles.headline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              account == null
                  ? 'Başvurun onaylanınca aynı profilin işletme moduna yükseltilir.'
                  : 'İşletme hesabı aynı profil üzerinde yönetilir.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isPending)
              _PendingApplicationCard(application: application!)
            else
              _ApplicationForm(
                formKey: _formKey,
                nameController: _nameController,
                phoneController: _phoneController,
                addressController: _addressController,
                customCategoryController: _customCategoryController,
                websiteController: _websiteController,
                descriptionController: _descriptionController,
                selectedCategory: _selectedCategory,
                onCategoryChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
                isLoading: state.isLoading,
                errorMessage: state.message,
                onSubmit: _submitApplication,
              ),
            if (account != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'İşletme hesabımı sil',
                isLoading: state.isLoading,
                variant: AppButtonVariant.outlined,
                onPressed: state.isLoading
                    ? null
                    : () => _confirmDeleteBusinessAccount(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final input = BusinessApplicationInput(
      businessName: _nameController.text,
      businessPhone: _phoneController.text,
      fullAddress: _addressController.text,
      category: _selectedCategory!,
      customCategory: _customCategoryController.text,
      website: _websiteController.text,
      description: _descriptionController.text,
    );
    final application = await ref
        .read(myBusinessAccountProvider.notifier)
        .submitApplication(input);

    if (!mounted || application == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İşletme başvurun alındı.')));
    context.goNamed(RouteNames.settings);
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.settings);
  }

  Future<void> _confirmDeleteBusinessAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('İşletme hesabını sil?'),
          content: const Text(
            'İşletme bilgilerin pasifleştirilecek ve gelecekteki işletme '
            'etkinliklerin yayından kaldırılacak. Hesabın kullanıcı hesabı '
            'olarak devam edecek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('İşletme hesabımı sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await ref
        .read(myBusinessAccountProvider.notifier)
        .deleteMyBusinessAccount();
    if (!context.mounted) return;

    if (!success) {
      final message = ref.read(myBusinessAccountProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'İşletme hesabı silinemedi. Tekrar dene.'),
        ),
      );
      return;
    }

    await ref.read(profileControllerProvider.notifier).loadMyProfile();
    final profile = ref.read(profileControllerProvider).profile;
    ref
        .read(authControllerProvider.notifier)
        .markProfileCompletion(isCompleted: profile?.hasCoreIdentity ?? false);
    await ref.read(myBusinessAccountProvider.notifier).loadMyBusinessAccount();
    await ref.read(eventsControllerProvider.notifier).refreshEvents();
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('İşletme hesabı silindi.')));
    context.goNamed(RouteNames.settings);
  }
}

class _ApplicationForm extends StatelessWidget {
  const _ApplicationForm({
    required this.formKey,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.customCategoryController,
    required this.websiteController,
    required this.descriptionController,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController customCategoryController;
  final TextEditingController websiteController;
  final TextEditingController descriptionController;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: _FormCard(
        child: Column(
          children: [
            AppTextField(
              label: 'İşletme adı',
              controller: nameController,
              prefixIcon: const Icon(Icons.storefront_outlined),
              validator: BusinessApplicationValidators.name,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'İşletme telefon numarası',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
              validator: BusinessApplicationValidators.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Ä°ÅŸletme kategorisi',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: BusinessCategories.values
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onCategoryChanged,
              validator: BusinessApplicationValidators.category,
            ),
            if (BusinessCategories.isOther(selectedCategory)) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Ä°ÅŸletme tÃ¼rÃ¼nÃ¼ yaz',
                controller: customCategoryController,
                prefixIcon: const Icon(Icons.edit_outlined),
                validator: (value) =>
                    BusinessApplicationValidators.customCategory(
                      category: selectedCategory,
                      value: value,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Tam konum/adres',
              controller: addressController,
              prefixIcon: const Icon(Icons.place_outlined),
              maxLines: 3,
              validator: BusinessApplicationValidators.fullAddress,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Website',
              controller: websiteController,
              keyboardType: TextInputType.url,
              prefixIcon: const Icon(Icons.language_outlined),
              validator: BusinessApplicationValidators.website,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Açıklama',
              controller: descriptionController,
              prefixIcon: const Icon(Icons.notes_outlined),
              maxLines: 3,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                errorMessage!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Başvur',
              isLoading: isLoading,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingApplicationCard extends StatelessWidget {
  const _PendingApplicationCard({required this.application});

  final BusinessApplication application;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İşletme başvurun inceleniyor.', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(application.businessName, style: AppTextStyles.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Text(application.fullAddress, style: AppTextStyles.bodySmall),
        ],
      ),
    );
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
