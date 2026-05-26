import 'dart:math';

class UserHandle {
  const UserHandle._();

  static final tagPattern = RegExp(r'^\d{4}$');

  static String? format(String? username, String? tag) {
    final cleanUsername = username?.trim();
    if (cleanUsername == null || cleanUsername.isEmpty) return null;

    final cleanTag = tag?.trim();
    if (cleanTag == null || cleanTag.isEmpty) return cleanUsername;
    if (cleanUsername.contains('#')) return cleanUsername;
    return '$cleanUsername#$cleanTag';
  }

  static String generateTag({Random? random}) {
    final generator = random ?? Random.secure();
    return generator.nextInt(10000).toString().padLeft(4, '0');
  }

  static bool isValidTag(String? value) {
    final cleanValue = value?.trim();
    return cleanValue != null && tagPattern.hasMatch(cleanValue);
  }
}

String? formatUserHandle(String? username, String? tag) {
  return UserHandle.format(username, tag);
}
