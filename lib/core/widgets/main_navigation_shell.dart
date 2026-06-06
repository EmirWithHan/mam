import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/responsive_layout.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final isTiny = AppResponsive.isTiny(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          isTiny ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.sm,
          isTiny ? AppSpacing.sm : AppSpacing.md,
          AppSpacing.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.xlBorder,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppRadius.xlBorder,
            child: NavigationBar(
              height: isTiny ? 64 : 72,
              labelBehavior: isTiny
                  ? NavigationDestinationLabelBehavior.alwaysHide
                  : NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => _goToTab(context, index),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Ana sayfa',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: 'Etkinlikler',
                ),
                NavigationDestination(
                  icon: Icon(Icons.add_circle, color: AppColors.primary),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Oluştur',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Sosyal',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToTab(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.goNamed(RouteNames.home);
        break;
      case 1:
        context.goNamed(RouteNames.events);
        break;
      case 2:
        context.goNamed(RouteNames.create);
        break;
      case 3:
        context.goNamed(RouteNames.social);
        break;
      case 4:
        context.goNamed(RouteNames.profile);
        break;
    }
  }
}
