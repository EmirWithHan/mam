import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/constants/auth_redirects.dart';
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
    return SupabaseService.client.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: kIsWeb ? null : AuthRedirects.googleOAuthCallback,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
