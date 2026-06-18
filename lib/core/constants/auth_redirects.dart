class AuthRedirects {
  const AuthRedirects._();

  static const mobileOAuthCallback = 'matchaman://login-callback/';
  static const mobileEmailConfirmationCallback = 'matchaman://auth/callback';
  static const mobilePasswordResetCallback = 'matchaman://reset-password';
  static const webOAuthOrigin = String.fromEnvironment('WEB_OAUTH_ORIGIN');

  static String oauthCallbackUrl({required bool isWeb}) {
    if (!isWeb) return mobileOAuthCallback;

    return webCallbackForPath('/auth/callback');
  }

  static String emailConfirmationUrl({required bool isWeb}) {
    if (!isWeb) return mobileEmailConfirmationCallback;

    return webCallbackForPath('/auth/callback');
  }

  static String passwordResetUrl({required bool isWeb}) {
    if (!isWeb) return mobilePasswordResetCallback;

    return webCallbackForPath('/reset-password');
  }

  static String webCallbackForPath(String path) {
    final configuredOrigin = webOAuthOrigin.trim();
    if (configuredOrigin.isNotEmpty) {
      return _webUrlForOrigin(configuredOrigin, path);
    }

    final origin = Uri.base.origin;
    if (origin.startsWith('http://') || origin.startsWith('https://')) {
      return _webUrlForOrigin(origin, path);
    }
    return path;
  }

  static String webOAuthCallbackForOrigin(String origin) {
    return _webUrlForOrigin(origin, '/auth/callback');
  }

  static String _webUrlForOrigin(String origin, String path) {
    final cleanOrigin = origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
    return '$cleanOrigin$path';
  }
}
