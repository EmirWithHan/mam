class RouteNames {
  const RouteNames._();

  static const splash = 'splash';
  static const auth = 'auth';
  static const accountDeletionPending = 'accountDeletionPending';
  static const login = 'login';
  static const register = 'register';
  static const emailVerification = 'emailVerification';
  static const forgotPassword = 'forgotPassword';
  static const resetPassword = 'resetPassword';
  static const authCallback = 'authCallback';
  static const profile = 'profile';
  static const usernameOnboarding = 'usernameOnboarding';
  static const publicProfile = 'publicProfile';
  static const profileFollowList = 'profileFollowList';
  static const profileGalleryViewer = 'profileGalleryViewer';
  static const profileComplete = 'profileComplete';
  static const settings = 'settings';
  static const feedback = 'feedback';
  static const rulesAndAgreements = 'rulesAndAgreements';
  static const privacyPolicy = 'privacyPolicy';
  static const termsOfUse = 'termsOfUse';
  static const communityGuidelines = 'communityGuidelines';
  static const eventSafetyDisclaimer = 'eventSafetyDisclaimer';
  static const support = 'support';
  static const blockedUsers = 'blockedUsers';
  static const businessCreate = 'businessCreate';
  static const businessPlus = 'businessPlus';
  static const businessProfile = 'businessProfile';
  static const admin = 'admin';
  static const notifications = 'notifications';
  static const followRequests = 'followRequests';
  static const trustScoreHistory = 'trustScoreHistory';
  static const feed = 'feed';
  static const create = 'create';
  static const createPost = 'createPost';
  static const postComments = 'postComments';
  static const events = 'events';
  static const social = 'social';
  static const userSearch = 'userSearch';
  static const eventDetail = 'eventDetail';
  static const eventChat = 'eventChat';
  static const createEvent = 'createEvent';
  static const editEvent = 'editEvent';
  static const home = 'home';
  static const directConversations = 'directConversations';
  static const directChat = 'directChat';
}

class RoutePaths {
  const RoutePaths._();

  static const splash = '/';
  static const auth = '/auth';
  static const accountDeletionPending = '/account-deletion-pending';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const emailVerification = '/auth/email-verification';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/reset-password';
  static const authCallback = '/auth/callback';
  static const profile = '/profile';
  static const usernameOnboarding = '/onboarding/username';
  static const publicProfile = '/profile/public/:userId';
  static const profileFollowList = '/profile/public/:userId/follows/:type';
  static const profileGalleryViewer = '/profile-gallery-viewer';
  static const profileComplete = '/profile/complete';
  static const settings = '/settings';
  static const feedback = '/settings/feedback';
  static const rulesAndAgreements = '/settings/rules-and-agreements';
  static const privacyPolicy = '/settings/privacy-policy';
  static const termsOfUse = '/settings/terms-of-use';
  static const communityGuidelines = '/settings/community-guidelines';
  static const eventSafetyDisclaimer = '/settings/event-safety-disclaimer';
  static const support = '/settings/support';
  static const blockedUsers = '/settings/blocked-users';
  static const businessCreate = '/business/create';
  static const businessPlus = '/business/plus';
  static const businessProfile = '/business/:businessId';
  static const admin = '/admin';
  static const notifications = '/notifications';
  static const followRequests = '/notifications/follow-requests';
  static const trustScoreHistory = '/profile/trust-score';
  static const feed = '/feed';
  static const create = '/create';
  static const createPost = '/feed/create';
  static const postComments = '/feed/:postId/comments';
  static const events = '/events';
  static const social = '/social';
  static const userSearch = '/social/search';
  static const eventDetail = '/events/:eventId';
  static const eventChat = '/events/:eventId/chat';
  static const createEvent = '/events/create';
  static const editEvent = '/events/:eventId/edit';
  static const home = '/home';
  static const directConversations = '/dms';
  static const directChat = '/dms/:conversationId';
  static const profileCompleteModeEventRequirements = 'eventRequirements';

  static bool isSafeReturnPath(String? value) {
    if (value == null || value.isEmpty) return false;
    if (!value.startsWith('/') || value.startsWith('//')) return false;

    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return !uri.hasScheme && uri.host.isEmpty;
  }
}
