import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../services/supabase_service.dart';

class AuthService {
  const AuthService();

  supabase.User? get currentUser => SupabaseService.client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  Stream<supabase.AuthState> get authStateChanges =>
      SupabaseService.client.auth.onAuthStateChange;

  Future<supabase.AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<supabase.AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return SupabaseService.client.auth.signUp(email: email, password: password);
  }

  Future<bool> signInWithGoogle() {
    return _signInWithOAuth(supabase.OAuthProvider.google, 'Google');
  }

  Future<bool> signInWithFacebook() {
    return _signInWithOAuth(supabase.OAuthProvider.facebook, 'Facebook');
  }

  Future<bool> _signInWithOAuth(
    supabase.OAuthProvider provider,
    String providerName,
  ) {
    final redirectTo = oauthRedirectTo(isWeb: kIsWeb);
    debugPrint(
      '[Auth] OAuth start provider=$providerName redirectTo=$redirectTo',
    );
    return SupabaseService.client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }

  @visibleForTesting
  static String oauthRedirectTo({required bool isWeb, Uri? baseUri}) {
    if (!isWeb) return 'matchaman://login-callback/';
    return webOAuthCallbackForOrigin((baseUri ?? Uri.base).origin);
  }

  @visibleForTesting
  static String webOAuthCallbackForOrigin(String origin) {
    final cleanOrigin = origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
    return '$cleanOrigin/auth/callback';
  }
}
