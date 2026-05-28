import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/auth/auth_models.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/oauth_callback_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/business/business_profile_page.dart';
import '../../features/business/create_business_account_page.dart';
import '../../features/chat/event_chat_page.dart';
import '../../features/events/create_event_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/events/events_page.dart';
import '../../features/feed/create_post_page.dart';
import '../../features/feed/post_comments_page.dart';
import '../../features/home/create_hub_page.dart';
import '../../features/home/home_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/profile/profile_completion_page.dart';
import '../../features/profile/profile_follow_list_page.dart';
import '../../features/profile/profile_follow_list_provider.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/public_profile_page.dart';
import '../../features/profile/widgets/profile_gallery_viewer_page.dart';
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
  _ensureWebPathUrlStrategy();

  return GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final uri = state.uri;
      final isInitializing =
          authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading;
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final needsProfileCompletion =
          isAuthenticated && !authState.isProfileCompleted;
      final isAuthRoute =
          location == RoutePaths.auth ||
          location == RoutePaths.login ||
          location == RoutePaths.register ||
          location == RoutePaths.authCallback;
      final isSplashRoute = location == RoutePaths.splash;
      final isProfileCompletionRoute = location == RoutePaths.profileComplete;

      debugPrint(
        '[Router] location=$location path=${uri.path} '
        'queryKeys=${uri.queryParameters.keys.join(',')} '
        'fragmentPresent=${uri.fragment.isNotEmpty} '
        'auth=${authState.status.name} profileDone=${authState.isProfileCompleted}',
      );

      if (_isOAuthReturnUri(uri) && location != RoutePaths.authCallback) {
        debugPrint('[Router] OAuth return detected; routing to auth callback');
        return RoutePaths.authCallback;
      }

      if (isInitializing) {
        return null;
      }

      if (isAuthenticated && (isAuthRoute || isSplashRoute)) {
        return needsProfileCompletion
            ? RoutePaths.profileComplete
            : RoutePaths.events;
      }

      if (needsProfileCompletion && !isProfileCompletionRoute) {
        return RoutePaths.profileComplete;
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
        path: RoutePaths.authCallback,
        name: RouteNames.authCallback,
        builder: (context, state) => const OAuthCallbackPage(),
      ),
      GoRoute(
        path: RoutePaths.profileGalleryViewer,
        name: RouteNames.profileGalleryViewer,
        builder: (context, state) {
          final args = state.extra is ProfileGalleryViewerArgs
              ? state.extra as ProfileGalleryViewerArgs
              : null;
          return MainNavigationShell(
            currentIndex: 4,
            child: ProfileGalleryViewerPage(args: args),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.publicProfile,
        name: RouteNames.publicProfile,
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return MainNavigationShell(
            currentIndex: 4,
            child: PublicProfilePage(userId: userId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.profileFollowList,
        name: RouteNames.profileFollowList,
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final type = _profileFollowListType(state.pathParameters['type']);
          return MainNavigationShell(
            currentIndex: 4,
            child: ProfileFollowListPage(userId: userId, type: type),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.profileComplete,
        name: RouteNames.profileComplete,
        builder: (context, state) => MainNavigationShell(
          currentIndex: 4,
          child: ProfileCompletionPage(
            mode:
                state.uri.queryParameters['mode'] ==
                    RoutePaths.profileCompleteModeEventRequirements
                ? RoutePaths.profileCompleteModeEventRequirements
                : null,
            returnTo:
                RoutePaths.isSafeReturnPath(
                  state.uri.queryParameters['returnTo'],
                )
                ? state.uri.queryParameters['returnTo']
                : null,
          ),
        ),
      ),
      GoRoute(
        path: RoutePaths.profile,
        name: RouteNames.profile,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 4, child: ProfilePage()),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 4, child: SettingsPage()),
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
        path: RoutePaths.businessCreate,
        name: RouteNames.businessCreate,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: CreateBusinessAccountPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.businessProfile,
        name: RouteNames.businessProfile,
        builder: (context, state) {
          final businessId = state.pathParameters['businessId'] ?? '';
          return MainNavigationShell(
            currentIndex: 4,
            child: BusinessProfilePage(businessId: businessId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsPage(),
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
        redirect: (context, state) => RoutePaths.home,
      ),
      GoRoute(
        path: RoutePaths.create,
        name: RouteNames.create,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 2, child: CreateHubPage()),
      ),
      GoRoute(
        path: RoutePaths.createPost,
        name: RouteNames.createPost,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 2, child: CreatePostPage()),
      ),
      GoRoute(
        path: RoutePaths.postComments,
        name: RouteNames.postComments,
        builder: (context, state) {
          final postId = state.pathParameters['postId'] ?? '';
          return MainNavigationShell(
            currentIndex: 0,
            child: PostCommentsPage(postId: postId),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.events,
        name: RouteNames.events,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 1, child: EventsPage()),
      ),
      GoRoute(
        path: RoutePaths.social,
        name: RouteNames.social,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 3, child: SocialPage()),
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
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 0, child: HomePage()),
      ),
    ],
  );
}

var _webPathUrlStrategyReady = false;

void _ensureWebPathUrlStrategy() {
  if (!kIsWeb || _webPathUrlStrategyReady) return;
  usePathUrlStrategy();
  _webPathUrlStrategyReady = true;
}

ProfileFollowListType _profileFollowListType(String? value) {
  if (value == 'following') return ProfileFollowListType.following;
  return ProfileFollowListType.followers;
}

bool _isOAuthReturnUri(Uri uri) {
  return uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error') ||
      uri.fragment.contains('access_token') ||
      uri.fragment.contains('error_description');
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
