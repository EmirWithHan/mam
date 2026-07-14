import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/auth/account_deletion_pending_page.dart';
import '../../features/auth/auth_models.dart';
import '../../features/auth/email_verification_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/oauth_callback_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/business/business_profile_page.dart';
import '../../features/admin/admin_dashboard_page.dart';
import '../../features/business/business_plus_page.dart';
import '../../features/business/create_business_account_page.dart';
import '../../features/chat/event_chat_page.dart';
import '../../features/direct_messages/direct_messages_page.dart';
import '../../features/direct_messages/direct_chat_page.dart';
import '../../features/events/create_event_page.dart';
import '../../features/events/event_detail_page.dart';
import '../../features/events/events_page.dart';
import '../../features/feed/create_post_page.dart';
import '../../features/feed/post_comments_page.dart';
import '../../features/feedback/feedback_page.dart';
import '../../features/home/create_hub_page.dart';
import '../../features/home/home_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/notifications/follow_requests_page.dart';
import '../../features/notifications/notifications_provider.dart';
import '../../features/profile/profile_completion_page.dart';
import '../../features/profile/profile_follow_list_page.dart';
import '../../features/profile/profile_follow_list_provider.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/username_onboarding_page.dart';
import '../../features/profile/public_profile_page.dart';
import '../../features/profile/widgets/profile_gallery_viewer_page.dart';
import '../../features/reports/blocked_users_page.dart';
import '../../features/settings/legal_info_page.dart';
import '../../features/settings/rules_and_agreements_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/social/social_page.dart';
import '../../features/trust_score/trust_score_history_page.dart';
import '../../features/user_search/user_search_page.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_loader.dart';
import '../widgets/main_navigation_shell.dart';
import 'route_names.dart';

GoRouter createAppRouter(AuthState authState) {
  _ensureWebPathUrlStrategy();

  final router = GoRouter(
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final uri = state.uri;
      final isInitializing =
          authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading;
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final needsEmailVerification =
          authState.status == AuthStatus.emailVerificationRequired;
      final isPasswordRecovery =
          authState.status == AuthStatus.passwordRecovery;
      final isAccountDeletionPending =
          authState.status == AuthStatus.accountDeletionRequested;
      final needsUsernameOnboarding =
          isAuthenticated && !authState.isProfileCompleted;
      final isAuthRoute =
          location == RoutePaths.auth ||
          location == RoutePaths.login ||
          location == RoutePaths.register ||
          location == RoutePaths.emailVerification ||
          location == RoutePaths.forgotPassword ||
          location == RoutePaths.resetPassword ||
          location == RoutePaths.authCallback;
      final isSplashRoute = location == RoutePaths.splash;
      final isUsernameOnboardingRoute =
          location == RoutePaths.usernameOnboarding;
      final isAccountDeletionPendingRoute =
          location == RoutePaths.accountDeletionPending;

      debugPrint(
        '[Router] location=$location path=${uri.path} '
        'queryKeys=${uri.queryParameters.keys.join(',')} '
        'fragmentPresent=${uri.fragment.isNotEmpty} '
        'auth=${authState.status.name} profileDone=${authState.isProfileCompleted}',
      );

      if (_isPasswordRecoveryReturnUri(uri) &&
          location != RoutePaths.resetPassword) {
        debugPrint('[Router] password recovery return detected');
        return RoutePaths.resetPassword;
      }

      if (_isOAuthReturnUri(uri) && location != RoutePaths.authCallback) {
        debugPrint('[Router] OAuth return detected; routing to auth callback');
        return RoutePaths.authCallback;
      }

      if (isPasswordRecovery && location != RoutePaths.resetPassword) {
        return RoutePaths.resetPassword;
      }

      if (isInitializing) {
        return null;
      }

      if (isAccountDeletionPending && !isAccountDeletionPendingRoute) {
        return RoutePaths.accountDeletionPending;
      }

      if (!isAccountDeletionPending && isAccountDeletionPendingRoute) {
        return isAuthenticated ? RoutePaths.events : RoutePaths.auth;
      }

      if (needsEmailVerification && !isAuthRoute) {
        debugPrint(
          '[Router] email confirmation pending allowed unauthenticated=true',
        );
        return RoutePaths.emailVerification;
      }

      if (isAuthenticated &&
          !isPasswordRecovery &&
          (isAuthRoute || isSplashRoute)) {
        return needsUsernameOnboarding
            ? RoutePaths.usernameOnboarding
            : RoutePaths.home;
      }

      if (needsUsernameOnboarding && !isUsernameOnboardingRoute) {
        return RoutePaths.usernameOnboarding;
      }

      if (!needsUsernameOnboarding && isUsernameOnboardingRoute) {
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
        builder: (context, state) => const _SplashPage(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: RoutePaths.accountDeletionPending,
        name: RouteNames.accountDeletionPending,
        builder: (context, state) => const AccountDeletionPendingPage(),
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
        path: RoutePaths.emailVerification,
        name: RouteNames.emailVerification,
        builder: (context, state) => EmailVerificationPage(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: RoutePaths.resetPassword,
        name: RouteNames.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
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
        path: RoutePaths.usernameOnboarding,
        name: RouteNames.usernameOnboarding,
        builder: (context, state) => const UsernameOnboardingPage(),
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
        path: RoutePaths.feedback,
        name: RouteNames.feedback,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 4, child: FeedbackPage()),
      ),
      GoRoute(
        path: RoutePaths.rulesAndAgreements,
        name: RouteNames.rulesAndAgreements,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: RulesAndAgreementsPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.privacyPolicy,
        name: RouteNames.privacyPolicy,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: LegalInfoPage(type: LegalInfoType.privacyPolicy),
        ),
      ),
      GoRoute(
        path: RoutePaths.termsOfUse,
        name: RouteNames.termsOfUse,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: LegalInfoPage(type: LegalInfoType.termsOfUse),
        ),
      ),
      GoRoute(
        path: RoutePaths.communityGuidelines,
        name: RouteNames.communityGuidelines,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: LegalInfoPage(type: LegalInfoType.communityGuidelines),
        ),
      ),
      GoRoute(
        path: RoutePaths.eventSafetyDisclaimer,
        name: RouteNames.eventSafetyDisclaimer,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: LegalInfoPage(type: LegalInfoType.eventSafetyDisclaimer),
        ),
      ),
      GoRoute(
        path: RoutePaths.support,
        name: RouteNames.support,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: LegalInfoPage(type: LegalInfoType.support),
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
        path: RoutePaths.businessCreate,
        name: RouteNames.businessCreate,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: CreateBusinessAccountPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.businessPlus,
        name: RouteNames.businessPlus,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: BusinessPlusPage(),
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
        path: RoutePaths.admin,
        name: RouteNames.admin,
        builder: (context, state) => const MainNavigationShell(
          currentIndex: 4,
          child: AdminDashboardPage(),
        ),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        name: RouteNames.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: RoutePaths.directConversations,
        name: RouteNames.directConversations,
        builder: (context, state) => const DirectConversationsPage(),
      ),
      GoRoute(
        path: RoutePaths.directChat,
        name: RouteNames.directChat,
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'] ?? '';
          return DirectChatPage(conversationId: conversationId);
        },
      ),
      GoRoute(
        path: RoutePaths.followRequests,
        name: RouteNames.followRequests,
        builder: (context, state) => const FollowRequestsPage(),
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
        path: RoutePaths.userSearch,
        name: RouteNames.userSearch,
        builder: (context, state) =>
            const MainNavigationShell(currentIndex: 3, child: UserSearchPage()),
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
        path: RoutePaths.editEvent,
        name: RouteNames.editEvent,
        builder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return MainNavigationShell(
            currentIndex: 1,
            child: CreateEventPage(eventId: eventId),
          );
        },
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
  configurePushNotificationRouteCallback(
    (data) => _routePushNotification(router, data),
  );
  return router;
}

bool _routePushNotification(GoRouter router, Map<String, dynamic> data) {
  final entityType = data['entity_type']?.toString().trim().toLowerCase();
  final entityId = data['entity_id']?.toString().trim();

  try {
    if (entityId != null && entityId.isNotEmpty) {
      if (entityType == 'direct_message') {
        router.pushNamed(
          RouteNames.directChat,
          pathParameters: {'conversationId': entityId},
        );
        return true;
      }
      if (entityType == 'event') {
        router.pushNamed(
          RouteNames.eventDetail,
          pathParameters: {'eventId': entityId},
        );
        return true;
      }
      if (entityType == 'profile' ||
          entityType == 'user' ||
          entityType == 'profile/user') {
        router.pushNamed(
          RouteNames.publicProfile,
          pathParameters: {'userId': entityId},
        );
        return true;
      }
    }

    router.pushNamed(RouteNames.notifications);
    return true;
  } catch (error) {
    debugPrint(
      '[Notifications] notification route failed: ${error.runtimeType}',
    );
    return false;
  }
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

bool _isPasswordRecoveryReturnUri(Uri uri) {
  final values = [
    uri.path,
    ...uri.queryParameters.values,
    uri.fragment,
  ].join(' ').toLowerCase();
  return values.contains('reset-password') ||
      values.contains('type=recovery') ||
      values.contains('recovery');
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
