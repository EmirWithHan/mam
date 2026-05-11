import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/auth/auth_models.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/chat/event_chat_page.dart';
import '../../features/events/create_event_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/events/events_page.dart';
import '../../features/feed/create_post_page.dart';
import '../../features/feed/feed_page.dart';
import '../../features/feed/post_comments_page.dart';
import '../../features/profile/profile_completion_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import 'route_names.dart';

GoRouter createAppRouter(AuthState authState) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isAuthRoute = location == RoutePaths.auth ||
          location == RoutePaths.login ||
          location == RoutePaths.register;
      final isSplashRoute = location == RoutePaths.splash;

      if (isAuthenticated && (isAuthRoute || isSplashRoute)) {
        return RoutePaths.home;
      }

      if (!isAuthenticated && !isAuthRoute) {
        return RoutePaths.auth;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) =>
            const _PlaceholderPage(title: 'Match A Man Foundation Ready'),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RoutePaths.register,
        name: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RoutePaths.profileComplete,
        name: RouteNames.profileComplete,
        builder: (context, state) => const ProfileCompletionPage(),
      ),
      GoRoute(
        path: RoutePaths.feed,
        name: RouteNames.feed,
        builder: (context, state) => const FeedPage(),
      ),
      GoRoute(
        path: RoutePaths.createPost,
        name: RouteNames.createPost,
        builder: (context, state) => const CreatePostPage(),
      ),
      GoRoute(
        path: RoutePaths.postComments,
        name: RouteNames.postComments,
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return PostCommentsPage(postId: postId);
        },
      ),
      GoRoute(
        path: RoutePaths.events,
        name: RouteNames.events,
        builder: (context, state) => const EventsPage(),
      ),
      GoRoute(
        path: RoutePaths.createEvent,
        name: RouteNames.createEvent,
        builder: (context, state) => const CreateEventPage(),
      ),
      GoRoute(
        path: RoutePaths.eventChat,
        name: RouteNames.eventChat,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return EventChatPage(eventId: eventId);
        },
      ),
      GoRoute(
        path: RoutePaths.eventDetail,
        name: RouteNames.eventDetail,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return EventDetailPage(eventId: eventId);
        },
      ),
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const _HomePlaceholderPage(),
      ),
    ],
  );
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePlaceholderPage extends ConsumerWidget {
  const _HomePlaceholderPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Match A Man',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Home placeholder',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Events',
                  onPressed: () => context.goNamed(RouteNames.events),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Feed',
                  onPressed: () => context.goNamed(RouteNames.feed),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Create post',
                  onPressed: () => context.goNamed(RouteNames.createPost),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Create event',
                  onPressed: () => context.goNamed(RouteNames.createEvent),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Complete profile',
                  onPressed: () =>
                      context.goNamed(RouteNames.profileComplete),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Logout',
                  isLoading: authState.isLoading,
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
