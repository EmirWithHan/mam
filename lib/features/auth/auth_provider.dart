import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_models.dart';
import 'auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return const AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState.initial());

  final AuthService _authService;

  Future<void> loginPlaceholder({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, message: null);
    await _authService.loginPlaceholder(email: email, password: password);
    state = state.copyWith(
      isLoading: false,
      message: 'Login will be connected soon.',
    );
  }

  Future<void> registerPlaceholder({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, message: null);
    await _authService.registerPlaceholder(email: email, password: password);
    state = state.copyWith(
      isLoading: false,
      message: 'Account creation will be connected soon.',
    );
  }
}
