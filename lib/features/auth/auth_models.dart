enum AuthStatus {
  initial,
  loading,
  authenticated,
  accountDeletionRequested,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.message,
    this.userId,
    this.isProfileCompleted = false,
  });

  const AuthState.initial()
    : status = AuthStatus.initial,
      message = null,
      userId = null,
      isProfileCompleted = false;

  const AuthState.loading()
    : status = AuthStatus.loading,
      message = null,
      userId = null,
      isProfileCompleted = false;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null,
      isProfileCompleted = false;

  const AuthState.authenticated({
    required this.userId,
    required this.isProfileCompleted,
    this.message,
  }) : status = AuthStatus.authenticated;

  const AuthState.accountDeletionRequested({
    required this.userId,
    this.message = 'Hesap silme talebin işleme alındı.',
  }) : status = AuthStatus.accountDeletionRequested,
       isProfileCompleted = false;

  const AuthState.error({required this.message})
    : status = AuthStatus.error,
      userId = null,
      isProfileCompleted = false;

  final AuthStatus status;
  final String? message;
  final String? userId;
  final bool isProfileCompleted;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    Object? message = _unset,
    Object? userId = _unset,
    bool? isProfileCompleted,
  }) {
    return AuthState(
      status: status ?? this.status,
      message: message == _unset ? this.message : message as String?,
      userId: userId == _unset ? this.userId : userId as String?,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
    );
  }
}

const _unset = Object();
