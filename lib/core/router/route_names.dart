class RouteNames {
  const RouteNames._();

  static const splash = 'splash';
  static const auth = 'auth';
  static const login = 'login';
  static const register = 'register';
  static const profile = 'profile';
  static const publicProfile = 'publicProfile';
  static const profileFollowList = 'profileFollowList';
  static const profileGalleryViewer = 'profileGalleryViewer';
  static const profileComplete = 'profileComplete';
  static const settings = 'settings';
  static const blockedUsers = 'blockedUsers';
  static const notifications = 'notifications';
  static const trustScoreHistory = 'trustScoreHistory';
  static const feed = 'feed';
  static const create = 'create';
  static const createPost = 'createPost';
  static const postComments = 'postComments';
  static const events = 'events';
  static const social = 'social';
  static const eventDetail = 'eventDetail';
  static const eventChat = 'eventChat';
  static const createEvent = 'createEvent';
  static const home = 'home';
}

class RoutePaths {
  const RoutePaths._();

  static const splash = '/';
  static const auth = '/auth';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const profile = '/profile';
  static const publicProfile = '/profile/public/:userId';
  static const profileFollowList = '/profile/public/:userId/follows/:type';
  static const profileGalleryViewer = '/profile-gallery-viewer';
  static const profileComplete = '/profile/complete';
  static const settings = '/settings';
  static const blockedUsers = '/settings/blocked-users';
  static const notifications = '/notifications';
  static const trustScoreHistory = '/profile/trust-score';
  static const feed = '/feed';
  static const create = '/create';
  static const createPost = '/feed/create';
  static const postComments = '/feed/:postId/comments';
  static const events = '/events';
  static const social = '/social';
  static const eventDetail = '/events/:eventId';
  static const eventChat = '/events/:eventId/chat';
  static const createEvent = '/events/create';
  static const home = '/home';
}
