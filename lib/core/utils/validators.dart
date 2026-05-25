import '../constants/turkey_locations.dart';

class Validators {
  const Validators._();

  static String? required(String? value, {String fieldName = 'Bu alan'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName gerekli.';
    }
    return null;
  }

  static String? email(String? value) {
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || !emailPattern.hasMatch(trimmed)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Şifre en az 8 karakter olmalı.';
    }
    if (value.length < 8) return 'Şifre en az 8 karakter olmalı.';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Şifre gerekli.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value != password) return 'Şifreler eşleşmiyor.';
    return null;
  }

  static String? username(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 3 || trimmed.length > 15) {
      return 'Kullanıcı adı 3-15 karakter olmalı.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) {
      return 'Kullanıcı adında sadece küçük harf, rakam ve alt çizgi kullan.';
    }
    return null;
  }

  static String? firstName(String? value) {
    return _name(value, minMessage: 'Ad en az 2 karakter olmalı.');
  }

  static String? lastName(String? value) {
    return _name(value, minMessage: 'Soyad en az 2 karakter olmalı.');
  }

  static String? _name(String? value, {required String minMessage}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 2) return minMessage;
    if (trimmed.length > 30) return 'En fazla 30 karakter kullan.';
    return null;
  }

  static String? city(String? value) {
    final city = value?.trim() ?? '';
    if (city.isEmpty) return 'Şehir seçmelisin.';
    if (!TurkeyLocations.isValidCity(city)) {
      return 'Geçerli bir şehir seçmelisin.';
    }
    return null;
  }

  static String? district(String? value, {required String city}) {
    final cityError = Validators.city(city);
    if (cityError != null) return 'Önce geçerli bir şehir seçmelisin.';

    final district = value?.trim() ?? '';
    if (district.isEmpty) return 'İlçe seçmelisin.';
    if (!TurkeyLocations.isValidDistrict(city, district)) {
      return 'Seçtiğin ilçe bu şehirle eşleşmiyor.';
    }
    return null;
  }

  static String? eventTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 3 || trimmed.length > 60) {
      return 'Etkinlik başlığı 3-60 karakter olmalı.';
    }
    return null;
  }

  static String? eventDescription(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 300) {
      return 'Açıklama en fazla 300 karakter olabilir.';
    }
    return null;
  }

  static String? sportType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Spor türü seçmelisin.';
    }
    return null;
  }

  static String? customSport(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 2 || trimmed.length > 30) {
      return 'Spor türü 2-30 karakter olmalı.';
    }
    return null;
  }

  static String? eventDate(DateTime? value) {
    if (value == null) return 'Etkinlik tarihi seçmelisin.';
    if (value.isBefore(DateTime.now())) return 'Geçmiş bir tarih seçemezsin.';
    return null;
  }

  static String? capacityTotal(String? value) {
    final capacity = int.tryParse(value?.trim() ?? '');
    if (capacity == null || capacity < 1) {
      return 'Katılımcı sayısı en az 1 olmalı.';
    }
    if (capacity > 100) return 'Katılımcı sayısı en fazla 100 olabilir.';
    return null;
  }

  static String? nonNegativeNumber(String? value) {
    final trimmed = value?.trim();
    final number = int.tryParse(
      trimmed == null || trimmed.isEmpty ? '0' : trimmed,
    );
    if (number == null || number < 0) return '0 veya daha büyük bir sayı gir.';
    if (number > 100) return 'Katılımcı sayısı en fazla 100 olabilir.';
    return null;
  }

  static String? postCaption(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 220) {
      return 'Açıklama en fazla 220 karakter olabilir.';
    }
    return null;
  }

  static String? bio(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 160) {
      return 'Bio en fazla 160 karakter olabilir.';
    }
    return null;
  }
}
