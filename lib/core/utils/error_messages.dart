import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'rate_limits.dart';

String friendlyErrorMessage(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();

  if (normalized.contains('rate_limit_exceeded')) {
    return 'Etkinlik veya işlem limitine ulaştın. Güvenilir sporcular günde 3, yeni sporcular günde 2, standart işletmeler ise ayda 3 etkinlik oluşturabilir. Limiti artırmak için Business Plus\'a geçebilirsin.';
  }

  if (isRateLimitError(error)) {
    return friendlyRateLimitMessage;
  }

  final authMessage = friendlyAuthErrorMessage(error);
  if (authMessage != null) return authMessage;

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
    return 'Kullanıcı adını seçerek başlayabilirsin.';
  }

  if (normalized.contains('bu etkinlik geçmişte kaldı') ||
      normalized.contains('event is past')) {
    return 'Bu etkinlik geçmişte kaldı.';
  }

  if (normalized.contains('bu etkinlik şu anda dolu') ||
      normalized.contains('event is full')) {
    return 'Bu etkinlik şu anda dolu.';
  }

  if (normalized.contains('event_full')) {
    return 'Bu etkinlik şu anda dolu.';
  }

  if (normalized.contains('event_edit_limit_reached')) {
    return 'Bu etkinlik yalnızca bir kez düzenlenebilir.';
  }

  if (normalized.contains('event_edit_window_closed')) {
    return 'Etkinliğe 15 dakikadan az kaldığı için düzenleme kapandı.';
  }

  if (normalized.contains('checkin_window_not_open')) {
    return 'QR okutma zamanı henüz başlamadı. Etkinlik saatine yaklaştığında tekrar dene.';
  }

  if (normalized.contains('checkin_window_closed')) {
    return 'QR okutma süresi sona erdi. Gerekirse manuel düzeltme kullan.';
  }

  if (normalized.contains('no_eligible_capacity')) {
    return 'Bu kullanıcı için uygun kontenjan kalmadı.';
  }

  if (normalized.contains('etkinlik konumunu yazmalısın')) {
    return 'Etkinlik konumunu yazmalısın.';
  }

  if (normalized.contains('join_request_not_pending')) {
    return 'Bu istek zaten güncellenmiş.';
  }

  if (normalized.contains('join_request_not_found')) {
    return 'Katılım isteği bulunamadı.';
  }

  if (normalized.contains('business_event_not_owned') ||
      normalized.contains('not_event_host')) {
    return 'Bu işlem için yetkin yok.';
  }

  if (normalized.contains('not_authenticated')) {
    return 'Bu işlem için giriş yapmalısın.';
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

  if (normalized.contains('profiles_phone_number_unique') ||
      (normalized.contains('phone_number') &&
          (normalized.contains('duplicate') ||
              normalized.contains('unique') ||
              normalized.contains('23505')))) {
    return 'Bu telefon numarası başka bir hesapta kullanılıyor.';
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

void logSupabaseDebug(String area, String action, Object error) {
  if (error is PostgrestException) {
    debugPrint(
      '[$area] $action failed code=${error.code ?? 'unknown'} '
      'message=${_safeDebugMessage(error.message)}',
    );
    return;
  }

  if (error is StorageException) {
    debugPrint(
      '[$area] $action failed status=${error.statusCode ?? 'unknown'} '
      'message=${_safeDebugMessage(error.message)}',
    );
    return;
  }

  debugPrint('[$area] $action failed type=${error.runtimeType}');
}

String _safeDebugMessage(String message) {
  final collapsed = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return 'empty';
  return collapsed.length <= 180
      ? collapsed
      : '${collapsed.substring(0, 180)}...';
}

String friendlyFeedLoadErrorMessage(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('pgrst202') ||
      normalized.contains('schema cache') ||
      normalized.contains('could not find the function')) {
    return 'Akış yüklenemedi.';
  }
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('failed host lookup')) {
    return 'Bağlantı sorunu oluştu. Tekrar dene.';
  }
  return 'Akış yüklenemedi.';
}

String friendlyFeedRefreshErrorMessage(Object error) {
  final normalized = error.toString().toLowerCase();
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('failed host lookup')) {
    return 'Bağlantı sorunu oluştu. Tekrar dene.';
  }
  return 'Akış yenilenemedi. Tekrar dene.';
}

String friendlyCreatePostErrorMessage(Object error) {
  final normalized = error.toString().toLowerCase();
  if (isRateLimitError(error)) {
    return friendlyRateLimitMessage;
  }
  if (normalized.contains('storage') ||
      normalized.contains('bucket') ||
      normalized.contains('upload')) {
    return 'Fotoğraf yüklenemedi. Tekrar dene.';
  }
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('failed host lookup')) {
    return 'Bağlantı sorunu oluştu. Tekrar dene.';
  }
  return 'Paylaşım oluşturulamadı. Tekrar dene.';
}

String? friendlyAuthErrorMessage(Object error) {
  final normalized = error.toString().toLowerCase();

  if (normalized.contains('email not confirmed')) {
    return 'E-posta adresini doğrulaman gerekiyor.';
  }
  if (normalized.contains('invalid login credentials') ||
      normalized.contains('invalid credentials')) {
    return 'E-posta veya şifre hatalı.';
  }
  if (normalized.contains('user already registered') ||
      normalized.contains('already registered') ||
      normalized.contains('already exists')) {
    return 'Bu e-posta ile kayıtlı bir hesap var. Giriş yapmayı deneyebilirsin.';
  }
  if (normalized.contains('weak password') ||
      normalized.contains('password should be') ||
      normalized.contains('password is too weak')) {
    return 'Daha güçlü bir şifre belirlemelisin.';
  }
  if (isRateLimitError(error) ||
      normalized.contains('rate limit') ||
      normalized.contains('too many') ||
      normalized.contains('429')) {
    return 'Çok sık deneme yaptın. Biraz bekleyip tekrar dene.';
  }
  if ((normalized.contains('expired') || normalized.contains('expire')) &&
      (normalized.contains('link') ||
          normalized.contains('token') ||
          normalized.contains('recovery'))) {
    return 'Bağlantının süresi dolmuş olabilir. Yeni bağlantı iste.';
  }
  if ((normalized.contains('invalid') || normalized.contains('malformed')) &&
      (normalized.contains('link') ||
          normalized.contains('token') ||
          normalized.contains('recovery'))) {
    return 'Bu bağlantı geçersiz görünüyor.';
  }
  if (normalized.contains('network') ||
      normalized.contains('socket') ||
      normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('failed host lookup')) {
    return 'Bağlantı sorunu var. Lütfen tekrar dene.';
  }
  if (normalized.contains('auth') ||
      normalized.contains('gotrue') ||
      normalized.contains('session')) {
    return 'İşlem tamamlanamadı. Lütfen tekrar dene.';
  }
  return null;
}
