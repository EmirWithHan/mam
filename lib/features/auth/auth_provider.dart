import 'dart:async';

import 'package:flutter/foundation.dart';
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
    : super(const AuthState.loading()) {
    final initialUser = _authService.currentUser;
    debugPrint('[Auth] controller init hasCurrentUser=${initialUser != null}');
    if (initialUser != null) {
      unawaited(_setAuthenticatedState(initialUser.id));
    } else {
      state = const AuthState.unauthenticated();
    }

    _authSubscription = _authService.authStateChanges.listen((authState) {
      if (!mounted) return;

      final user = authState.session?.user;
      debugPrint(
        '[Auth] auth state event=${authState.event.name} '
        'sessionRestored=${authState.session != null}',
      );
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

  Future<void> _setAuthenticatedState(String userId, {String? message}) async {
    try {
      debugPrint('[Auth] loading profile for authenticated user');
      final profile = await _profileService.createEmptyProfileIfMissing();
      if (!mounted) return;
      if (profile.hasDeletionRequested) {
        debugPrint('[Auth] authenticated account is restricted');
        state = AuthState.accountDeletionRequested(userId: userId);
        return;
      }
      debugPrint(
        '[Auth] authenticated profileCompleted=${profile.hasCoreIdentity}',
      );
      state = AuthState.authenticated(
        userId: userId,
        isProfileCompleted: profile.hasCoreIdentity,
        message: message,
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint('[Auth] profile load failed: ${friendlyErrorMessage(error)}');
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        debugPrint('[Auth] preserving session after profile bootstrap failure');
        state = AuthState.authenticated(
          userId: currentUser.id,
          isProfileCompleted: false,
          message: message,
        );
        return;
      }
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
      final session = response.session;

      if (user == null || session == null) {
        state = const AuthState.error(message: 'Giriş işlemi tamamlanamadı.');
        return;
      }

      await _setAuthenticatedState(user.id, message: 'Giriş yapıldı.');
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
      final session = response.session;

      if (user == null) {
        state = const AuthState.error(message: 'Giriş işlemi tamamlanamadı.');
        return;
      }

      if (session == null) {
        state = const AuthState.unauthenticated(
          message:
              'Hesabın oluşturuldu. E-posta doğrulaması gerekiyorsa gelen kutunu kontrol et.',
        );
        return;
      }

      await _setAuthenticatedState(user.id, message: 'Hesabın oluşturuldu.');
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
  }

  Future<void> signInWithGoogle() async {
    await _startSocialSignIn(
      startOAuth: _authService.signInWithGoogle,
      providerName: 'Google',
    );
  }

  Future<void> signInWithFacebook() async {
    await _startSocialSignIn(
      startOAuth: _authService.signInWithFacebook,
      providerName: 'Facebook',
    );
  }

  Future<void> _startSocialSignIn({
    required Future<bool> Function() startOAuth,
    required String providerName,
  }) async {
    state = const AuthState.loading();

    try {
      debugPrint('[Auth] social OAuth start provider=$providerName');
      final launched = await startOAuth();
      if (!launched) {
        state = const AuthState.unauthenticated(message: 'İşlem iptal edildi.');
      }
    } on supabase.AuthException catch (error) {
      state = AuthState.error(message: _socialAuthError(error, providerName));
    } catch (error) {
      state = AuthState.error(message: _socialAuthError(error, providerName));
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

String _socialAuthError(Object error, String providerName) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('cancel') || normalized.contains('dismiss')) {
    return 'İşlem iptal edildi.';
  }
  if (providerName == 'Facebook') {
    return 'Facebook ile giriş tamamlanamadı.';
  }
  return '$providerName ile giriş başlatılamadı.';
}
