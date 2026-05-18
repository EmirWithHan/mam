String friendlyErrorMessage(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();

  if (normalized.contains('notifications') ||
      normalized.contains('bildirim')) {
    if (normalized.contains('permission') ||
        normalized.contains('policy') ||
        normalized.contains('rls') ||
        normalized.contains('not authorized') ||
        normalized.contains('forbidden') ||
        normalized.contains('42501') ||
        normalized.contains('yetkin yok')) {
      return 'Bu işlem için yetkin yok.';
    }
    if (normalized.contains('update') ||
        normalized.contains('mark_notification_read') ||
        normalized.contains('mark_all_notifications_read') ||
        normalized.contains('güncellenemedi')) {
      return 'Bildirim güncellenemedi.';
    }
    if (normalized.contains('select') ||
        normalized.contains('load') ||
        normalized.contains('fetch') ||
        normalized.contains('yüklenemedi')) {
      return 'Bildirimler yüklenemedi.';
    }
  }

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

  if (normalized.contains('bio') &&
      (normalized.contains('160') ||
          normalized.contains('check') ||
          normalized.contains('constraint'))) {
    return 'Bio en fazla 160 karakter olabilir.';
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
