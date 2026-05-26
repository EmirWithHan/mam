String friendlyErrorMessage(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();

  if (normalized.contains('notifications') ||
      normalized.contains('notification') ||
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

  if (normalized.contains('profil bilgileri kontrol edilemedi')) {
    return 'Profil bilgileri kontrol edilemedi.';
  }

  if (normalized.contains('etkinliklere katılmak') ||
      normalized.contains('event profile')) {
    return 'Etkinliklere katılmak için profilini tamamlamalısın.';
  }

  if (normalized.contains('bu etkinlik geçmişte kaldı') ||
      normalized.contains('event is past')) {
    return 'Bu etkinlik geçmişte kaldı.';
  }

  if (normalized.contains('bu etkinlik şu anda dolu') ||
      normalized.contains('event is full') ||
      normalized.contains('capacity')) {
    return 'Bu etkinlik şu anda dolu.';
  }

  if (normalized.contains('email not confirmed')) {
    return 'E-posta doğrulaması gerekiyorsa gelen kutunu kontrol et.';
  }

  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
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
    return 'Bu kullanıcı adı alınmış.';
  }

  if (normalized.contains('tag') &&
      (normalized.contains('profiles_tag_check') ||
          normalized.contains('profile tag') ||
          normalized.contains('user tag') ||
          normalized.contains('constraint') ||
          normalized.contains('23514'))) {
    return 'Profil etiketi oluşturulamadı. Tekrar dene.';
  }

  if (normalized.contains('kullanıcı adı en az 2') ||
      normalized.contains('username_min') ||
      (normalized.contains('username') && normalized.contains('too short'))) {
    return 'Kullanıcı adı en az 2 karakter olmalı.';
  }

  if (normalized.contains('kullanıcı adı sadece') ||
      normalized.contains('username_format') ||
      normalized.contains('invalid username') ||
      (normalized.contains('username') &&
          (normalized.contains('check') ||
              normalized.contains('constraint') ||
              normalized.contains('invalid')))) {
    return 'Kullanıcı adı sadece harf, rakam ve _ içerebilir.';
  }

  if ((normalized.contains('profile') || normalized.contains('profiles')) &&
      (normalized.contains('save') ||
          normalized.contains('update') ||
          normalized.contains('insert') ||
          normalized.contains('could not be created') ||
          normalized.contains('pgrst116') ||
          normalized.contains('cannot coerce') ||
          normalized.contains('23514') ||
          normalized.contains('profiles_completed_required_fields'))) {
    return 'Profil kaydedilemedi. Tekrar dene.';
  }

  if (normalized.contains('bio') &&
      (normalized.contains('160') ||
          normalized.contains('check') ||
          normalized.contains('constraint'))) {
    return 'Bio en fazla 160 karakter olabilir.';
  }

  if (normalized.contains('yorumlar gizlendi')) {
    return 'Yorumlar gizlendi.';
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
