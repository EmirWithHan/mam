class AuthRedirects {
  const AuthRedirects._();

  static const mobileOAuthCallback = 'matchaman://login-callback/';
  static const webOAuthOrigin = String.fromEnvironment('WEB_OAUTH_ORIGIN');

  static String oauthCallbackUrl({required bool isWeb}) {
    if (!isWeb) return mobileOAuthCallback;

    final configuredOrigin = webOAuthOrigin.trim();
    if (configuredOrigin.isNotEmpty) {
      return webOAuthCallbackForOrigin(configuredOrigin);
    }

    final origin = Uri.base.origin;
    if (origin.startsWith('http://') || origin.startsWith('https://')) {
      return webOAuthCallbackForOrigin(origin);
    }
    return '/auth/callback';
  }

  static String webOAuthCallbackForOrigin(String origin) {
    final cleanOrigin = origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
    return '$cleanOrigin/auth/callback';
  }
}
