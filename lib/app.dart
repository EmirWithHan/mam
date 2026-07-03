import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_models.dart';
import 'features/notifications/notifications_provider.dart';

class MatchAManApp extends StatelessWidget {
  final List<Override> overrides;

  const MatchAManApp({super.key, this.overrides = const []});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides,
      child: const _MatchAManRouterApp(),
    );
  }
}

class _MatchAManRouterApp extends ConsumerWidget {
  const _MatchAManRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    _syncPushRegistration(ref, authState);
    ref.listen(authControllerProvider, (previous, next) {
      _syncPushRegistration(ref, next, previous: previous);
    });

    return MaterialApp.router(
      title: 'Akanzi',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      routerConfig: createAppRouter(authState),
    );
  }
}

void _syncPushRegistration(
  WidgetRef ref,
  AuthState authState, {
  AuthState? previous,
}) {
  final pushController = ref.read(pushRegistrationControllerProvider);
  final isReady =
      authState.status == AuthStatus.authenticated &&
      authState.isProfileCompleted &&
      authState.hasAcceptedTerms;

  pushController.debugAuthReadiness(
    isAuthenticated: authState.status == AuthStatus.authenticated,
    hasUserId: authState.userId?.trim().isNotEmpty ?? false,
    isProfileCompleted: authState.isProfileCompleted,
    hasAcceptedTerms: authState.hasAcceptedTerms,
  );

  if (isReady) {
    unawaited(pushController.initializeForAuthenticatedUser());
    return;
  }

  if (previous?.status == AuthStatus.authenticated &&
      authState.status != AuthStatus.authenticated) {
    unawaited(pushController.deleteCurrentToken());
  }
}
