class PhoneVerification {
  const PhoneVerification._();

  static const verificationComingSoonMessage =
      'Telefon doğrulama yakında eklenecek.';

  static String normalize(String? value) {
    return normalizeTurkishPhoneNumber(value) ?? '';
  }

  static String? validateOptional(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (normalizeTurkishPhoneNumber(raw) != null) return null;
    return 'Geçerli bir telefon numarası gir.';
  }

  static bool isPhoneVerified(dynamic profile) {
    final phone = profile?.phoneNumber?.toString().trim();
    return profile?.phoneVerified == true && phone != null && phone.isNotEmpty;
  }

  static bool canRequirePhoneForBusinessFlow(dynamic profile) {
    return isPhoneVerified(profile);
  }

  static bool canMarkVerifiedWithoutOtp() {
    return false;
  }

  static String statusLabel(dynamic profile) {
    return isPhoneVerified(profile) ? 'Doğrulandı' : 'Doğrulanmadı';
  }

  static String friendlyDuplicateError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('profiles_phone_number_unique') ||
        (normalized.contains('phone_number') &&
            (normalized.contains('duplicate') ||
                normalized.contains('unique') ||
                normalized.contains('23505')))) {
      return 'Bu telefon numarası başka bir hesapta kullanılıyor.';
    }
    return 'Geçerli bir telefon numarası gir.';
  }
}

String? normalizeTurkishPhoneNumber(String? input) {
  final trimmed = input?.trim() ?? '';
  if (trimmed.isEmpty) return null;

  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;

  String national;
  final compact = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  if (compact.startsWith('+90')) {
    national = digits.substring(2);
  } else if (compact.startsWith('0090')) {
    national = digits.substring(4);
  } else if (compact.startsWith('0')) {
    national = digits.substring(1);
  } else if (compact.startsWith('5')) {
    national = digits;
  } else {
    return null;
  }

  if (!RegExp(r'^5[0-9]{9}$').hasMatch(national)) return null;
  if (RegExp(r'^([0-9])\1{9}$').hasMatch(national)) return null;
  if (_hasSuspiciousRepeatedPattern(national)) return null;

  return '+90$national';
}

bool _hasSuspiciousRepeatedPattern(String national) {
  for (var size = 1; size <= 5; size++) {
    if (national.length % size != 0) continue;
    final part = national.substring(0, size);
    if (part * (national.length ~/ size) == national) return true;
  }
  return false;
}
