enum AuthStatus {
  unauthenticated,
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.isLoading = false,
    this.message,
  });

  const AuthState.initial()
      : status = AuthStatus.unauthenticated,
        isLoading = false,
        message = null;

  final AuthStatus status;
  final bool isLoading;
  final String? message;

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? message,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      message: message ?? this.message,
    );
  }
}
