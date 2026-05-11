import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_provider.dart';

class MatchAManApp extends StatelessWidget {
  const MatchAManApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _MatchAManRouterApp());
  }
}

class _MatchAManRouterApp extends ConsumerWidget {
  const _MatchAManRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp.router(
      title: 'Match A Man',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: createAppRouter(authState),
    );
  }
}
