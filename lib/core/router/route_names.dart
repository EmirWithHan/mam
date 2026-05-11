class RouteNames {
  const RouteNames._();

  static const splash = 'splash';
  static const auth = 'auth';
  static const login = 'login';
  static const register = 'register';
  static const profileComplete = 'profileComplete';
  static const feed = 'feed';
  static const createPost = 'createPost';
  static const postComments = 'postComments';
  static const events = 'events';
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
  static const profileComplete = '/profile/complete';
  static const feed = '/feed';
  static const createPost = '/feed/create';
  static const postComments = '/feed/:postId/comments';
  static const events = '/events';
  static const eventDetail = '/events/:eventId';
  static const eventChat = '/events/:eventId/chat';
  static const createEvent = '/events/create';
  static const home = '/home';
}
