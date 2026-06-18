import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_loader.dart';
import 'auth_models.dart';
import 'auth_provider.dart';

class OAuthCallbackPage extends ConsumerStatefulWidget {
  const OAuthCallbackPage({super.key});

  @override
  ConsumerState<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends ConsumerState<OAuthCallbackPage> {
  Timer? _fallbackTimer;
  bool _showFailure = false;
  late final String _failureMessage;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    _failureMessage = _authFailureMessage(uri);
    debugPrint(
      '[AuthCallback] reached path=${uri.path} '
      'queryKeys=${uri.queryParameters.keys.join(',')} '
      'fragmentPresent=${uri.fragment.isNotEmpty}',
    );
    _fallbackTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final authState = ref.read(authControllerProvider);
      debugPrint(
        '[AuthCallback] fallback check sessionRestored='
        '${authState.status == AuthStatus.authenticated}',
      );
      if (authState.status == AuthStatus.unauthenticated ||
          authState.status == AuthStatus.error) {
        setState(() => _showFailure = true);
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    if (authState.status == AuthStatus.passwordRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.goNamed(RouteNames.resetPassword);
      });
    }

    if (authState.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final routeName = authState.isProfileCompleted
            ? RouteNames.events
            : RouteNames.usernameOnboarding;
        debugPrint('[AuthCallback] route decision=$routeName');
        context.goNamed(routeName);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _showFailure
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _failureMessage,
                        style: AppTextStyles.title,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Girişe dön',
                        onPressed: () => context.goNamed(RouteNames.login),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoader(),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Giriş tamamlanıyor...',
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

String _authFailureMessage(Uri uri) {
  final values = [
    ...uri.queryParameters.values,
    uri.fragment,
  ].join(' ').toLowerCase();
  if (values.contains('expired') || values.contains('invalid')) {
    return 'Bağlantı geçersiz veya süresi dolmuş olabilir.';
  }
  return 'Giriş işlemi tamamlanamadı.';
}
