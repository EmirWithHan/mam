import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../settings/legal_info_page.dart';
import 'auth_models.dart';
import 'auth_provider.dart';
import 'widgets/social_auth_buttons.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isShowingEmailVerificationDialog = false;
  bool _hasAcceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_ensureTermsAccepted()) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    debugPrint('[Auth] register submit started');
    final result = await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
          termsAccepted: _hasAcceptedTerms,
        );

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);

    if (_requiresEmailVerificationDialog(authState) ||
        result is EmailVerificationRequired ||
        authState.needsEmailVerification) {
      debugPrint(
        '[Auth] email confirmation required, showing verification dialog',
      );
      await _showEmailVerificationDialog();
      return;
    }

    if (authState.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.message!)));
    }
  }

  bool _requiresEmailVerificationDialog(AuthState authState) {
    final message = authState.message;
    if (authState.status != AuthStatus.unauthenticated || message == null) {
      return false;
    }

    return _looksLikeEmailVerificationMessage(message);
  }

  Future<void> _showEmailVerificationDialog() async {
    if (_isShowingEmailVerificationDialog) return;

    _isShowingEmailVerificationDialog = true;
    try {
      final shouldGoToLogin = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('E-postanı kontrol et'),
            content: const Text(
              'Hesabını oluşturduk. Devam etmek için e-posta adresine gönderilen doğrulama bağlantısına tıkla.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Giriş ekranına dön'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldGoToLogin != true) return;
      context.goNamed(RouteNames.login);
    } finally {
      _isShowingEmailVerificationDialog = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_ensureTermsAccepted()) return;

    await _startSocialSignIn(
      ref.read(authControllerProvider.notifier).signInWithGoogle,
    );
  }

  Future<void> _signInWithApple() async {
    if (!_ensureTermsAccepted()) return;

    await _startSocialSignIn(
      ref.read(authControllerProvider.notifier).signInWithApple,
    );
  }

  bool _ensureTermsAccepted() {
    if (_hasAcceptedTerms) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Devam etmek için Kullanıcı Sözleşmesi’ni kabul etmelisin.',
        ),
      ),
    );
    return false;
  }

  Future<void> _startSocialSignIn(Future<void> Function() startSignIn) async {
    await startSignIn();

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);

    if (authState.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.message!)));
    }
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
    final authState = ref.watch(authControllerProvider);

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
              Text('Aramıza katıl', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Etkinlikleri keşfetmek ve topluluğa dahil olmak için hesap oluştur.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.xlBorder,
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFFFF9F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.09),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFFF0EA),
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: AppResponsive.cardPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (authState.message != null &&
                          !_isEmailVerificationSuccess(authState)) ...[
                        _AuthErrorCard(message: authState.message!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppTextField(
                        label: 'E-posta',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.mail_outline),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Şifre',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Şifre tekrar',
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        validator: (value) => Validators.confirmPassword(
                          value,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _TermsAcceptanceRow(
                        value: _hasAcceptedTerms,
                        onChanged: (value) {
                          setState(() => _hasAcceptedTerms = value ?? false);
                        },
                        onOpenTerms: _openTerms,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Kayıt Ol',
                        isLoading: authState.isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SocialAuthButtons(
                        isLoading: authState.isLoading,
                        onGooglePressed: _signInWithGoogle,
                        onApplePressed: _signInWithApple,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.goNamed(RouteNames.login),
                child: const Text('Zaten hesabın var mı? Giriş yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isEmailVerificationSuccess(AuthState authState) {
  return authState.needsEmailVerification ||
      authState.status == AuthStatus.unauthenticated &&
          _looksLikeEmailVerificationMessage(authState.message);
}

bool _looksLikeEmailVerificationMessage(String? message) {
  if (message == null) return false;

  final normalized = message.toLowerCase();
  final mentionsEmail =
      normalized.contains('e-posta') || normalized.contains('email');
  final mentionsVerification =
      normalized.contains('doğrulama') ||
      normalized.contains('dogrulama') ||
      normalized.contains('bağlantı') ||
      normalized.contains('baglanti') ||
      normalized.contains('link') ||
      normalized.contains('kontrol') ||
      normalized.contains('check') ||
      normalized.contains('verify') ||
      normalized.contains('verification') ||
      normalized.contains('confirm');

  return mentionsEmail && mentionsVerification;
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

class _AuthErrorCard extends StatelessWidget {
  const _AuthErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
        borderRadius: AppRadius.mdBorder,
      ),
      child: Padding(
        padding: AppResponsive.cardPadding(context),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
          ],
        ),
      ),
    );
  }
}
