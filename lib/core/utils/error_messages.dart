String friendlyErrorMessage(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();

  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials') ||
      normalized.contains('email not confirmed')) {
    return 'E-posta veya şifre hatalı.';
  }

  if (normalized.contains('user already registered') ||
      normalized.contains('already registered') ||
      normalized.contains('already exists')) {
    return 'Bu e-posta ile zaten hesap oluşturulmuş.';
  }

  if ((normalized.contains('username') ||
          normalized.contains('profiles_username_key')) &&
      (normalized.contains('duplicate') ||
          normalized.contains('unique') ||
          normalized.contains('already') ||
          normalized.contains('23505'))) {
    return 'Bu kullanıcı adı zaten kullanılıyor.';
  }

  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('failed host lookup')) {
    return 'Bağlantı sorunu oluştu. Tekrar dene.';
  }

  if (normalized.contains('permission') ||
      normalized.contains('policy') ||
      normalized.contains('rls') ||
      normalized.contains('not authorized') ||
      normalized.contains('forbidden') ||
      normalized.contains('42501')) {
    return 'Bu işlem için yetkin yok.';
  }

  if (normalized.contains('storage') ||
      normalized.contains('bucket') ||
      normalized.contains('upload')) {
    return 'Dosya yüklenirken sorun oluştu.';
  }

  if (normalized.contains('jwt') || normalized.contains('signed in')) {
    return 'Bu işlem için giriş yapmalısın.';
  }

  if (message.trim().isEmpty) return 'Bir şeyler ters gitti. Tekrar dene.';
  if (message.length <= 90 &&
      !normalized.contains('postgrest') &&
      !normalized.contains('exception')) {
    return message;
  }
  return 'Bir şeyler ters gitti. Tekrar dene.';
}
