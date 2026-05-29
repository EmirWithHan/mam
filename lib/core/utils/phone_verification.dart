class PhoneVerification {
  const PhoneVerification._();

  static String normalize(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '';

    var digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('00')) {
      digits = '+${digits.substring(2)}';
    }
    if (digits.startsWith('+90')) {
      return '+90${digits.substring(3).replaceAll(RegExp(r'[^0-9]'), '')}';
    }

    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('90') && digits.length == 12) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) {
      return '+90${digits.substring(1)}';
    }
    if (digits.length == 10 && digits.startsWith('5')) return '+90$digits';
    return digits;
  }

  static String? validateOptional(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final normalized = normalize(raw);
    if (RegExp(r'^\+905[0-9]{9}$').hasMatch(normalized)) return null;
    return 'Geçerli bir telefon numarası gir.';
  }

  static bool isPhoneVerified(dynamic profile) {
    final phone = profile?.phoneNumber?.toString().trim();
    return profile?.phoneVerified == true && phone != null && phone.isNotEmpty;
  }

  static bool canRequirePhoneForBusinessFlow(dynamic profile) {
    return isPhoneVerified(profile);
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
