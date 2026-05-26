class AuthRedirects {
  const AuthRedirects._();

  static const mobileOAuthCallback = 'matchaman://login-callback/';
  static const webLocalOAuthCallback = 'http://localhost:3000/auth/callback';

  static String oauthCallbackUrl({required bool isWeb}) {
    if (!isWeb) return mobileOAuthCallback;

    final origin = Uri.base.origin;
    if (origin.startsWith('http://') || origin.startsWith('https://')) {
      return webOAuthCallbackForOrigin(origin);
    }
    return webLocalOAuthCallback;
  }

  static String webOAuthCallbackForOrigin(String origin) {
    final cleanOrigin = origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
    return '$cleanOrigin/auth/callback';
  }
}
