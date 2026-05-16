import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/auth/auth_models.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/chat/event_chat_page.dart';
import '../../features/events/create_event_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/events/events_page.dart';
import '../../features/feed/create_post_page.dart';
import '../../features/feed/feed_page.dart';
import '../../features/feed/post_comments_page.dart';
import '../../features/home/create_hub_page.dart';
import '../../features/profile/profile_completion_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/reports/blocked_users_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/social/social_page.dart';
import '../../features/trust_score/trust_score_history_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_loader.dart';
import '../widgets/main_navigation_shell.dart';
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
        return RoutePaths.events;
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
        builder: (context, state) => const _SplashPage(),
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
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: ProfileCompletionPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.profile,
        name: RouteNames.profile,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: ProfilePage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: SettingsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.blockedUsers,
        name: RouteNames.blockedUsers,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: BlockedUsersPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.trustScoreHistory,
        name: RouteNames.trustScoreHistory,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: TrustScoreHistoryPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.feed,
        name: RouteNames.feed,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 0,
          child: FeedPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.create,
        name: RouteNames.create,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 2,
          child: CreateHubPage(),
        ),
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
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 1,
          child: EventsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.social,
        name: RouteNames.social,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 3,
          child: SocialPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.createEvent,
        name: RouteNames.createEvent,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 1,
          child: CreateEventPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.eventChat,
        name: RouteNames.eventChat,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return MainNavigationShell(
            currentIndex: 1,
            child: EventChatPage(eventId: eventId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.eventDetail,
        name: RouteNames.eventDetail,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return MainNavigationShell(
            currentIndex: 1,
            child: EventDetailPage(eventId: eventId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 0,
          child: FeedPage(),
        ),
      ),
    ],
  );
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(size: 72, showText: true),
              SizedBox(height: AppSpacing.lg),
              SizedBox(width: 32, height: 32, child: AppLoader()),
            ],
          ),
        ),
      ),
    );
  }
}
