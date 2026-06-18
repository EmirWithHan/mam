enum AuthStatus {
  initial,
  loading,
  authenticated,
  emailVerificationRequired,
  passwordRecovery,
  accountDeletionRequested,
  unauthenticated,
  error,
}

class AuthState {
  const AuthState({
    required this.status,
    this.message,
    this.userId,
    this.pendingEmail,
    this.isProfileCompleted = false,
    this.hasAcceptedTerms = false,
  });

  const AuthState.initial()
    : status = AuthStatus.initial,
      message = null,
      userId = null,
      pendingEmail = null,
      isProfileCompleted = false,
      hasAcceptedTerms = false;

  const AuthState.loading()
    : status = AuthStatus.loading,
      message = null,
      userId = null,
      pendingEmail = null,
      isProfileCompleted = false,
      hasAcceptedTerms = false;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null,
      pendingEmail = null,
      isProfileCompleted = false,
      hasAcceptedTerms = false;

  const AuthState.authenticated({
    required this.userId,
    required this.isProfileCompleted,
    required this.hasAcceptedTerms,
    this.message,
  }) : status = AuthStatus.authenticated,
       pendingEmail = null;

  const AuthState.emailVerificationRequired({
    required this.pendingEmail,
    this.message = 'Doğrulama bağlantısı e-postana gönderildi.',
  }) : status = AuthStatus.emailVerificationRequired,
       userId = null,
       isProfileCompleted = false,
       hasAcceptedTerms = false;

  const AuthState.passwordRecovery({this.userId, this.message})
    : status = AuthStatus.passwordRecovery,
      pendingEmail = null,
      isProfileCompleted = false,
      hasAcceptedTerms = false;

  const AuthState.accountDeletionRequested({
    required this.userId,
    this.message = 'Hesap silme talebin işleme alındı.',
  }) : status = AuthStatus.accountDeletionRequested,
       pendingEmail = null,
       isProfileCompleted = false,
       hasAcceptedTerms = false;

  const AuthState.error({required this.message})
    : status = AuthStatus.error,
      userId = null,
      pendingEmail = null,
      isProfileCompleted = false,
      hasAcceptedTerms = false;

  final AuthStatus status;
  final String? message;
  final String? userId;
  final String? pendingEmail;
  final bool isProfileCompleted;
  final bool hasAcceptedTerms;

  bool get isLoading => status == AuthStatus.loading;
  bool get needsEmailVerification =>
      status == AuthStatus.emailVerificationRequired;
  bool get isPasswordRecovery => status == AuthStatus.passwordRecovery;

  AuthState copyWith({
    AuthStatus? status,
    Object? message = _unset,
    Object? userId = _unset,
    Object? pendingEmail = _unset,
    bool? isProfileCompleted,
    bool? hasAcceptedTerms,
  }) {
    return AuthState(
      status: status ?? this.status,
      message: message == _unset ? this.message : message as String?,
      userId: userId == _unset ? this.userId : userId as String?,
      pendingEmail: pendingEmail == _unset
          ? this.pendingEmail
          : pendingEmail as String?,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
    );
  }
}

const _unset = Object();

sealed class EmailSignUpResult {
  const EmailSignUpResult();
}

class EmailSignUpAuthenticated extends EmailSignUpResult {
  const EmailSignUpAuthenticated({required this.userId});

  final String userId;
}

class EmailVerificationRequired extends EmailSignUpResult {
  const EmailVerificationRequired({required this.email});

  final String email;
}

class AuthLinkMessages {
  const AuthLinkMessages._();

  static String resendConfirmationError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (_isRateLimit(normalized)) {
      return 'Çok sık bağlantı istedin. Biraz bekleyip tekrar dene.';
    }
    if (_isInvalidEmail(normalized)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (_isNetwork(normalized)) {
      return 'Bağlantı sorunu var. Lütfen tekrar dene.';
    }
    return 'Doğrulama e-postası gönderilemedi.';
  }

  static String passwordResetError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (_isRateLimit(normalized)) {
      return 'Çok sık bağlantı istedin. Biraz bekleyip tekrar dene.';
    }
    if (_isInvalidEmail(normalized)) {
      return 'Geçerli bir e-posta adresi gir.';
    }
    if (_isNetwork(normalized)) {
      return 'Bağlantı sorunu var. Lütfen tekrar dene.';
    }
    return 'Şifre sıfırlama bağlantısı gönderilemedi.';
  }

  static String updatePasswordError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('session') ||
        normalized.contains('missing') ||
        normalized.contains('expired') ||
        normalized.contains('invalid') ||
        normalized.contains('token')) {
      return 'Şifre sıfırlama bağlantısı geçersiz veya süresi dolmuş olabilir.';
    }
    if (normalized.contains('weak') || normalized.contains('password')) {
      return 'Şifre en az 8 karakter olmalı.';
    }
    if (_isNetwork(normalized)) {
      return 'Bağlantı sorunu var. Lütfen tekrar dene.';
    }
    return 'Şifre güncellenemedi. Tekrar dene.';
  }

  static bool _isRateLimit(String normalized) {
    return normalized.contains('rate') ||
        normalized.contains('too many') ||
        normalized.contains('429');
  }

  static bool _isInvalidEmail(String normalized) {
    return normalized.contains('invalid email') ||
        normalized.contains('email address');
  }

  static bool _isNetwork(String normalized) {
    return normalized.contains('socket') ||
        normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('failed host lookup');
  }
}
