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
import 'auth_provider.dart';
import 'widgets/social_auth_buttons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);

    if (authState.needsEmailVerification) {
      final email = authState.pendingEmail ?? _emailController.text.trim();
      context.goNamed(
        RouteNames.emailVerification,
        queryParameters: {'email': email},
      );
      if (authState.message != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authState.message!)));
      }
      return;
    }

    if (authState.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.message!)));
    }
  }

  Future<void> _signInWithGoogle() async {
    await _startSocialSignIn(
      ref.read(authControllerProvider.notifier).signInWithGoogle,
    );
  }

  Future<void> _signInWithApple() async {
    await _startSocialSignIn(
      ref.read(authControllerProvider.notifier).signInWithApple,
    );
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
              Text('Tekrar hoş geldin', style: AppTextStyles.headline),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Etkinliklere dönmek için giriş yap.',
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
                      if (authState.message != null) ...[
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
                        validator: Validators.loginPassword,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Giriş Yap',
                        isLoading: authState.isLoading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: authState.isLoading
                              ? null
                              : () =>
                                    context.goNamed(RouteNames.forgotPassword),
                          child: const Text('Şifremi unuttum'),
                        ),
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
                onPressed: () => context.goNamed(RouteNames.register),
                child: const Text('Hesabın yok mu? Kayıt ol'),
              ),
            ],
          ),
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
