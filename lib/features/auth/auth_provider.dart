import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/utils/error_messages.dart';
import '../../core/utils/validators.dart';
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
      if (authState.event == supabase.AuthChangeEvent.passwordRecovery) {
        state = AuthState.passwordRecovery(
          userId: user?.id,
          message: 'Yeni şifreni belirleyebilirsin.',
        );
        return;
      }
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
        '[Auth] authenticated minimumProfile=${profile.hasMinimumProfile}',
      );
      state = AuthState.authenticated(
        userId: userId,
        isProfileCompleted: profile.hasMinimumProfile,
        hasAcceptedTerms: _authService.currentUserHasAcceptedTerms,
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
          hasAcceptedTerms: _authService.currentUserHasAcceptedTerms,
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
    final normalizedEmail = email.trim();

    try {
      final response = await _authService.signInWithEmailAndPassword(
        email: normalizedEmail,
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
      if (_isEmailNotConfirmedError(error)) {
        state = AuthState.emailVerificationRequired(
          pendingEmail: normalizedEmail,
          message: 'E-posta adresini doğrulaman gerekiyor.',
        );
        return;
      }
      state = AuthState.error(message: friendlyErrorMessage(error));
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
    }
  }

  Future<EmailSignUpResult?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required bool termsAccepted,
  }) async {
    if (!termsAccepted) {
      state = const AuthState.error(
        message: 'Devam etmek için Kullanıcı Sözleşmesi’ni kabul etmelisin.',
      );
      return null;
    }

    state = const AuthState.loading();
    final normalizedEmail = email.trim();

    try {
      final result = await _authService.signUpWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
        termsAcceptedAt: DateTime.now(),
      );

      switch (result) {
        case EmailVerificationRequired(:final email):
          state = AuthState.emailVerificationRequired(pendingEmail: email);
          return result;
        case EmailSignUpAuthenticated(:final userId):
          await _setAuthenticatedState(userId, message: 'Hesabın oluşturuldu.');
          return result;
      }
    } on supabase.AuthException catch (error) {
      if (_isAlreadyRegisteredError(error)) {
        state = const AuthState.error(
          message:
              'Bu e-posta ile kayıtlı bir hesap var. Giriş yapmayı deneyebilirsin.',
        );
        return null;
      }
      state = AuthState.error(message: friendlyErrorMessage(error));
      return null;
    } catch (error) {
      state = AuthState.error(message: friendlyErrorMessage(error));
      return null;
    }
  }

  Future<bool> resendSignupConfirmationEmail(String email) async {
    final normalizedEmail = email.trim();
    if (Validators.email(normalizedEmail) != null) {
      state = AuthState.emailVerificationRequired(
        pendingEmail: normalizedEmail,
        message: 'Geçerli bir e-posta adresi gir.',
      );
      return false;
    }

    state = const AuthState.loading();
    try {
      await _authService.resendSignupConfirmationEmail(normalizedEmail);
      state = AuthState.emailVerificationRequired(
        pendingEmail: normalizedEmail,
        message: 'Doğrulama bağlantısı tekrar gönderildi.',
      );
      return true;
    } on supabase.AuthException catch (error) {
      state = AuthState.emailVerificationRequired(
        pendingEmail: normalizedEmail,
        message: AuthLinkMessages.resendConfirmationError(error),
      );
      return false;
    } catch (error) {
      state = AuthState.emailVerificationRequired(
        pendingEmail: normalizedEmail,
        message: AuthLinkMessages.resendConfirmationError(error),
      );
      return false;
    }
  }

  Future<void> sendPasswordResetLink(String email) async {
    final normalizedEmail = email.trim();
    final emailError = Validators.email(normalizedEmail);
    if (emailError != null) {
      state = AuthState.error(message: 'Geçerli bir e-posta adresi gir.');
      return;
    }

    state = const AuthState.loading();
    try {
      await _authService.sendPasswordResetLink(normalizedEmail);
      state = const AuthState.unauthenticated(
        message: 'Şifre sıfırlama bağlantısı e-postana gönderildi.',
      );
    } on supabase.AuthException catch (error) {
      state = AuthState.error(
        message: AuthLinkMessages.passwordResetError(error),
      );
    } catch (error) {
      state = AuthState.error(
        message: AuthLinkMessages.passwordResetError(error),
      );
    }
  }

  Future<void> updatePassword(String password) async {
    state = const AuthState.loading();
    try {
      await _authService.updatePassword(password);
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        state = const AuthState.unauthenticated(message: 'Şifren güncellendi.');
        return;
      }
      await _setAuthenticatedState(
        currentUser.id,
        message: 'Şifren güncellendi.',
      );
    } on supabase.AuthException catch (error) {
      state = AuthState.passwordRecovery(
        userId: _authService.currentUser?.id,
        message: AuthLinkMessages.updatePasswordError(error),
      );
    } catch (error) {
      state = AuthState.passwordRecovery(
        userId: _authService.currentUser?.id,
        message: AuthLinkMessages.updatePasswordError(error),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    await _startSocialSignIn(
      startOAuth: _authService.signInWithGoogle,
      providerName: 'Google',
    );
  }

  Future<void> signInWithApple() async {
    await _startSocialSignIn(
      startOAuth: _authService.signInWithApple,
      providerName: 'Apple',
    );
  }

  Future<bool> acceptTerms() async {
    final currentState = state;
    if (currentState.status != AuthStatus.authenticated) return false;
    if (currentState.hasAcceptedTerms) return true;

    try {
      await _authService.acceptTerms(termsAcceptedAt: DateTime.now());
      if (!mounted) return false;
      state = currentState.copyWith(hasAcceptedTerms: true);
      return true;
    } on supabase.AuthException catch (error) {
      if (!mounted) return false;
      state = currentState.copyWith(message: friendlyErrorMessage(error));
      return false;
    } catch (error) {
      if (!mounted) return false;
      state = currentState.copyWith(message: friendlyErrorMessage(error));
      return false;
    }
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
  return '$providerName ile giriş başlatılamadı.';
}

bool _isEmailNotConfirmedError(Object error) {
  return error.toString().toLowerCase().contains('email not confirmed');
}

bool _isAlreadyRegisteredError(Object error) {
  final normalized = error.toString().toLowerCase();
  return normalized.contains('already registered') ||
      normalized.contains('already exists') ||
      normalized.contains('user already registered');
}
