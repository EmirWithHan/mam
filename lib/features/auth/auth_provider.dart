import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/utils/error_messages.dart';
import 'auth_models.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return const AuthService();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
      return AuthController(ref.watch(authServiceProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(_initialState(_authService)) {
    _authSubscription = _authService.authStateChanges.listen((authState) {
      final user = authState.session?.user;
      if (user == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      state = AuthState.authenticated(userId: user.id);
    });
  }

  final AuthService _authService;
  late final StreamSubscription<supabase.AuthState> _authSubscription;

  static AuthState _initialState(AuthService authService) {
    final user = authService.currentUser;
    if (user == null) return const AuthState.unauthenticated();
    return AuthState.authenticated(userId: user.id);
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();

    try {
      final response = await _authService.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;

      if (user == null) {
        state = const AuthState.error(message: 'E-posta veya şifre hatalı.');
        return;
      }

      state = AuthState.authenticated(userId: user.id);
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
  }

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();

    try {
      final response = await _authService.signUpWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;

      if (user == null) {
        state = const AuthState.error(
          message: 'Hesap oluşturulamadı. Tekrar dene.',
        );
        return;
      }

      state = AuthState.authenticated(userId: user.id);
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
  }

  Future<void> signOut() async {
    state = const AuthState.loading();

    try {
      await _authService.signOut();
      state = const AuthState.unauthenticated();
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
