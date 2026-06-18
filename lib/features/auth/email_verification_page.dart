import 'dart:async';

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
import 'auth_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  String get _email => widget.email.trim().isNotEmpty
      ? widget.email.trim()
      : ref.read(authControllerProvider).pendingEmail?.trim() ?? '';

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .resendSignupConfirmationEmail(_email);

    if (!mounted) return;
    final authState = ref.read(authControllerProvider);
    if (authState.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authState.message!)));
    }
    if (success) _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 45);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
        return;
      }
      setState(() => _cooldownSeconds--);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final email = _email;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const AppLogo(size: 32, showText: true),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppResponsive.pagePadding(context),
          children: [
            Text('E-postanı doğrula', style: AppTextStyles.headline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hesabını oluşturduk. Devam etmek için e-posta adresine gönderilen doğrulama bağlantısına tıkla.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.lg),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: AppRadius.xlBorder,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: AppResponsive.cardPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('E-posta', style: AppTextStyles.bodyStrong),
                    const SizedBox(height: AppSpacing.xs),
                    Text(email, style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.lg),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        border: Border.all(color: AppColors.border),
                        borderRadius: AppRadius.mdBorder,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.mark_email_read_outlined),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Bağlantıyı açtıktan sonra uygulamaya dönüp giriş yapabilirsin.',
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _cooldownSeconds > 0
                          ? 'E-postayı tekrar gönder ($_cooldownSeconds)'
                          : 'E-postayı tekrar gönder',
                      isLoading: isLoading,
                      onPressed:
                          isLoading || email.isEmpty || _cooldownSeconds > 0
                          ? null
                          : _resend,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.goNamed(RouteNames.login),
                      child: const Text('Giriş ekranına dön'),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.goNamed(RouteNames.register),
                      child: const Text('E-postayı değiştir'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
