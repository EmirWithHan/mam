import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../services/supabase_service.dart';

class AuthService {
  const AuthService();

  supabase.User? get currentUser => SupabaseService.client.auth.currentUser;

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
    return SupabaseService.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await SupabaseService.client.auth.signOut();
  }
}
