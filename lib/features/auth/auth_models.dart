enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.message,
    this.userId,
  });

  const AuthState.initial()
    : status = AuthStatus.initial,
      message = null,
      userId = null;

  const AuthState.loading()
    : status = AuthStatus.loading,
      message = null,
      userId = null;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null;

  const AuthState.authenticated({required this.userId})
    : status = AuthStatus.authenticated,
      message = null;

  const AuthState.error({required this.message})
    : status = AuthStatus.error,
      userId = null;

  final AuthStatus status;
  final String? message;
  final String? userId;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    Object? message = _unset,
    Object? userId = _unset,
  }) {
    return AuthState(
      status: status ?? this.status,
      message: message == _unset ? this.message : message as String?,
      userId: userId == _unset ? this.userId : userId as String?,
    );
  }
}

const _unset = Object();
