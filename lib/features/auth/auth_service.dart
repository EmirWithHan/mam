import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/constants/auth_redirects.dart';
import '../../services/supabase_service.dart';
import 'auth_models.dart';

const termsVersion = 'terms_v1_2026_06_10';

class AuthService {
  const AuthService();

  supabase.User? get currentUser => SupabaseService.client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  bool get currentUserHasAcceptedTerms {
    return hasAcceptedTermsMetadata(currentUser?.userMetadata);
  }

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

  Future<EmailSignUpResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required DateTime termsAcceptedAt,
  }) async {
    final normalizedEmail = email.trim();
    final response = await SupabaseService.client.auth.signUp(
      email: normalizedEmail,
      password: password,
      emailRedirectTo: AuthRedirects.emailConfirmationUrl(isWeb: kIsWeb),
      data: {
        'termsAccepted': true,
        'termsAcceptedAt': termsAcceptedAt.toUtc().toIso8601String(),
        'termsVersion': termsVersion,
      },
    );
    final user = response.user;
    debugPrint(
      '[Auth] signUp success sessionPresent=${response.session != null}',
    );
    if (user == null) {
      throw const supabase.AuthException('Sign up failed.');
    }
    if (response.session == null) {
      return EmailVerificationRequired(email: normalizedEmail);
    }
    return EmailSignUpAuthenticated(userId: user.id);
  }

  Future<void> resendSignupConfirmationEmail(String email) async {
    await SupabaseService.client.auth.resend(
      email: email.trim(),
      type: supabase.OtpType.signup,
      emailRedirectTo: AuthRedirects.emailConfirmationUrl(isWeb: kIsWeb),
    );
  }

  Future<void> sendPasswordResetLink(String email) {
    return SupabaseService.client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AuthRedirects.passwordResetUrl(isWeb: kIsWeb),
    );
  }

  Future<supabase.UserResponse> updatePassword(String password) {
    return SupabaseService.client.auth.updateUser(
      supabase.UserAttributes(password: password),
    );
  }

  Future<supabase.UserResponse> acceptTerms({
    required DateTime termsAcceptedAt,
  }) {
    final metadata = {
      ...?currentUser?.userMetadata,
      'termsAccepted': true,
      'termsAcceptedAt': termsAcceptedAt.toUtc().toIso8601String(),
      'termsVersion': termsVersion,
    };
    return SupabaseService.client.auth.updateUser(
      supabase.UserAttributes(data: metadata),
    );
  }

  Future<bool> signInWithGoogle() {
    return _signInWithOAuth(supabase.OAuthProvider.google, 'Google');
  }

  Future<bool> signInWithApple() {
    return _signInWithOAuth(supabase.OAuthProvider.apple, 'Apple');
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
    if (!isWeb) return AuthRedirects.mobileOAuthCallback;
    return webOAuthCallbackForOrigin((baseUri ?? Uri.base).origin);
  }

  @visibleForTesting
  static String webOAuthCallbackForOrigin(String origin) {
    final cleanOrigin = origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
    return '$cleanOrigin/auth/callback';
  }

  @visibleForTesting
  static bool hasAcceptedTermsMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return false;
    return metadata['termsAccepted'] == true &&
        metadata['termsVersion'] == termsVersion &&
        metadata['termsAcceptedAt']?.toString().trim().isNotEmpty == true;
  }
}
