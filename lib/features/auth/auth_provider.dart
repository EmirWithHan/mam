import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/utils/error_messages.dart';
import '../profile/profile_provider.dart';
import '../profile/profile_service.dart';
import 'auth_models.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return const AuthService();
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.watch(authServiceProvider),
      ref.watch(profileServiceProvider),
    );
  },
);

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService, this._profileService)
    : super(_initialState(_authService)) {
    _authSubscription = _authService.authStateChanges.listen((authState) {
      final user = authState.session?.user;
      if (user == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      unawaited(_setAuthenticatedState(user.id));
    });
  }

  final AuthService _authService;
  final ProfileService _profileService;
  late final StreamSubscription<supabase.AuthState> _authSubscription;

  static AuthState _initialState(AuthService authService) {
    final user = authService.currentUser;
    if (user == null) return const AuthState.unauthenticated();
    return AuthState.authenticated(userId: user.id, isProfileCompleted: false);
  }

  Future<void> _setAuthenticatedState(String userId) async {
    try {
      final profile = await _profileService.createEmptyProfileIfMissing();
      if (!mounted) return;
      state = AuthState.authenticated(
        userId: userId,
        isProfileCompleted: profile.isProfileCompleted,
      );
    } catch (error) {
      if (!mounted) return;
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
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

      await _setAuthenticatedState(user.id);
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

      await _setAuthenticatedState(user.id);
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthState.loading();

    try {
      final launched = await _authService.signInWithGoogle();
      if (!launched) {
        state = const AuthState.unauthenticated(message: 'İşlem iptal edildi.');
        return;
      }
      state = const AuthState.unauthenticated();
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: _googleAuthError(error));
    } catch (error) {
      state = AuthState.error(message: _googleAuthError(error));
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

  void markProfileCompletion({required bool isCompleted}) {
    if (state.status != AuthStatus.authenticated) return;
    state = state.copyWith(isProfileCompleted: isCompleted);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}

String _googleAuthError(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('cancel') || normalized.contains('dismiss')) {
    return 'İşlem iptal edildi.';
  }
  if (normalized.contains('already') ||
      normalized.contains('exists') ||
      normalized.contains('registered') ||
      normalized.contains('identity')) {
    return 'Bu e-posta ile zaten hesap oluşturulmuş. E-posta ile giriş yapmayı dene.';
  }
  if (normalized.contains('launch') || normalized.contains('url')) {
    return 'Google ile giriş başlatılamadı.';
  }
  return 'Giriş işlemi tamamlanamadı. Tekrar dene.';
}
