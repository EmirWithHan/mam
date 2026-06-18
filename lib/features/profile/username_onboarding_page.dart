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
import '../settings/legal_info_page.dart';
import 'profile_models.dart';
import 'profile_provider.dart';

class UsernameOnboardingPage extends ConsumerStatefulWidget {
  const UsernameOnboardingPage({super.key});

  @override
  ConsumerState<UsernameOnboardingPage> createState() =>
      _UsernameOnboardingPageState();
}

class _UsernameOnboardingPageState
    extends ConsumerState<UsernameOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _hasAcceptedTerms = false;

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
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authState = ref.read(authControllerProvider);
    final needsTermsAcceptance = !authState.hasAcceptedTerms;
    if (needsTermsAcceptance && !_hasAcceptedTerms) {
      _showTermsRequiredError();
      return;
    }

    if (needsTermsAcceptance) {
      final accepted = await ref
          .read(authControllerProvider.notifier)
          .acceptTerms();
      if (!mounted) return;
      if (!accepted) {
        final message = ref.read(authControllerProvider).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ??
                  'Devam etmek için Kullanıcı Sözleşmesi’ni kabul etmelisin.',
            ),
          ),
        );
        return;
      }
    }

    final profile = await ref
        .read(profileControllerProvider.notifier)
        .updateUsername(_usernameController.text);
    if (!mounted) return;

    if (profile == null) {
      final message = ref.read(profileControllerProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ?? 'Kullanıcı adı kaydedilemedi. Lütfen tekrar dene.',
          ),
        ),
      );
      return;
    }

    ref
        .read(authControllerProvider.notifier)
        .markProfileCompletion(isCompleted: profile.hasMinimumProfile);
    context.goNamed(RouteNames.events);
  }

  void _showTermsRequiredError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Devam etmek için Kullanıcı Sözleşmesi’ni kabul etmelisin.',
        ),
      ),
    );
  }

  Future<void> _openTerms() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return const FractionallySizedBox(
          heightFactor: 0.92,
          child: LegalInfoPage(type: LegalInfoType.termsOfUse),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final needsTermsAcceptance = !authState.hasAcceptedTerms;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppResponsive.pagePadding(context),
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Kullanıcı adını seç', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Uygulamada seni bu kullanıcı adıyla göstereceğiz. Profilini daha sonra istediğin zaman tamamlayabilirsin.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              DecoratedBox(
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
                  padding: AppResponsive.cardPadding(context),
                  child: AppTextField(
                    label: 'Kullanıcı adı',
                    hintText: 'ornek_kullanici',
                    controller: _usernameController,
                    prefixIcon: const Icon(Icons.alternate_email),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: ProfileUsername.validate,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Profil bilgilerini daha sonra Profil sayfasından düzenleyebilirsin.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              if (needsTermsAcceptance) ...[
                const SizedBox(height: AppSpacing.md),
                _TermsAcceptanceRow(
                  value: _hasAcceptedTerms,
                  onChanged: (value) {
                    setState(() => _hasAcceptedTerms = value ?? false);
                  },
                  onOpenTerms: _openTerms,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Devam et',
                isLoading: profileState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsAcceptanceRow extends StatelessWidget {
  const _TermsAcceptanceRow({
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.mdBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(value: value, onChanged: onChanged),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onOpenTerms,
                    child: Text(
                      'Kullanıcı Sözleşmesi',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '’ni okudum ve kabul ediyorum.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
