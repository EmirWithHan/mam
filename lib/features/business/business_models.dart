import '../../core/utils/user_handle.dart';

class BusinessCategories {
  const BusinessCategories._();

  static const other = 'Diğer';

  static const values = [
    'Halı Saha',
    'Futbol Sahası',
    'Basketbol Sahası',
    'Voleybol Salonu',
    'Tenis Kortu',
    'Padel Kortu',
    'Spor Salonu',
    'CrossFit Salonu',
    'Pilates Stüdyosu',
    'Yoga Stüdyosu',
    'Dövüş Sporları Salonu',
    'Yüzme Havuzu',
    'Buz Pisti',
    'Atletizm Tesisi',
    'At Çiftliği',
    'Outdoor / Doğa',
    'Kamp Alanı',
    'Trekking / Yürüyüş Rotası',
    'Tırmanış Salonu',
    'Paintball Alanı',
    'Airsoft Alanı',
    'Bisiklet Parkuru',
    'Su Sporları Merkezi',
    'Kayak / Snowboard Tesisi',
    'Bowling Salonu',
    'Bilardo Salonu',
    'Dart / Oyun Alanı',
    'Kafe',
    'Board Game Kafe',
    'Etkinlik Mekanı',
    'Workshop Alanı',
    'Dans Stüdyosu',
    'E-Spor / Gaming Alanı',
    'Spor Akademisi',
    'Kişisel Antrenör',
    'Dans Eğitmeni',
    'Yoga Eğitmeni',
    'Outdoor Rehberi',
    'Workshop Eğitmeni',
    'Etkinlik Organizasyonu',
    'Tur / Gezi Organizasyonu',
    'Kulüp / Topluluk',
    'Fotoğraf / Video Hizmeti',
    'Ekipman Kiralama',
    other,
  ];

  static bool isValid(String? value) {
    final trimmed = value?.trim();
    return trimmed != null && values.contains(trimmed);
  }

  static bool isOther(String? value) {
    final trimmed = value?.trim();
    return trimmed == other || trimmed == 'Diğer';
  }

  static List<String> allowedEventActivities({
    required String? category,
    String? customCategory,
  }) {
    final normalized = _normalizeCategory(
      isOther(category) ? customCategory : category,
    );
    if (normalized.contains('at ciftligi')) {
      return const ['At Binme', 'Doğa Gezisi', 'Outdoor'];
    }
    if (normalized.contains('hali saha') ||
        normalized.contains('futbol sahasi')) {
      return const ['Futbol'];
    }
    if (normalized.contains('basketbol')) return const ['Basketbol'];
    if (normalized.contains('voleybol')) return const ['Voleybol'];
    if (normalized.contains('tenis')) return const ['Tenis'];
    if (normalized.contains('padel')) return const ['Padel'];
    if (normalized.contains('yoga')) return const ['Yoga'];
    if (normalized.contains('pilates')) return const ['Pilates'];
    if (normalized.contains('spor salonu') ||
        normalized.contains('fitness') ||
        normalized.contains('crossfit')) {
      return const ['Fitness'];
    }
    if (normalized.contains('outdoor') ||
        normalized.contains('doga') ||
        normalized.contains('kamp') ||
        normalized.contains('trekking') ||
        normalized.contains('yuruyus')) {
      return const ['Trekking', 'Kamp', 'Outdoor'];
    }
    if (isOther(category)) return const ['Diğer'];
    return const ['Diğer'];
  }

  static bool canCreateActivity({
    required String? category,
    String? customCategory,
    required String activity,
  }) {
    final allowed = allowedEventActivities(
      category: category,
      customCategory: customCategory,
    );
    if (isOther(category)) return activity.trim().length >= 2;
    final normalizedActivity = _normalizeCategory(activity);
    return allowed.any(
      (value) => _normalizeCategory(value) == normalizedActivity,
    );
  }
}

class BusinessAccount {
  const BusinessAccount({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.username,
    this.businessTag,
    required this.category,
    this.customCategory,
    required this.city,
    required this.district,
    this.address,
    this.description,
    this.phone,
    this.website,
    this.instagram,
    this.logoUrl,
    this.coverUrl,
    this.isVerified = false,
    this.status = BusinessAccountStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String username;
  final String? businessTag;
  final String category;
  final String? customCategory;
  final String city;
  final String district;
  final String? address;
  final String? description;
  final String? phone;
  final String? website;
  final String? instagram;
  final String? logoUrl;
  final String? coverUrl;
  final bool isVerified;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'İşletme';
    return trimmed;
  }

  String? get displayHandle => formatUserHandle(username, businessTag);

  String get statusLabel => BusinessAccountStatus.labelFor(status);

  String get badgeLabel => BusinessBadgeLabels.forVerified(isVerified);

  String get displayCategory {
    final custom = customCategory?.trim();
    if (BusinessCategories.isOther(category) &&
        custom != null &&
        custom.isNotEmpty) {
      return custom;
    }
    final trimmed = category.trim();
    if (trimmed.isEmpty) return 'Kategori belirtilmedi';
    return trimmed;
  }

  String get locationLabel {
    final cityValue = city.trim();
    final districtValue = district.trim();
    if (cityValue.isEmpty && districtValue.isEmpty) return 'Konum belirtilmedi';
    if (districtValue.isEmpty) return cityValue;
    if (cityValue.isEmpty) return districtValue;
    return '$cityValue / $districtValue';
  }

  bool get isPubliclyVisible => status == BusinessAccountStatus.active;

  factory BusinessAccount.fromJson(Map<String, dynamic> json) {
    return BusinessAccount(
      id: json['id']?.toString() ?? '',
      ownerUserId: json['owner_user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      businessTag: json['business_tag']?.toString(),
      category: json['category']?.toString() ?? '',
      customCategory: _nullableString(json['custom_category']),
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      address: _nullableString(json['address']),
      description: _nullableString(json['description']),
      phone: _nullableString(json['phone']),
      website: _nullableString(json['website']),
      instagram: _nullableString(json['instagram']),
      logoUrl: _nullableString(json['logo_url']),
      coverUrl: _nullableString(json['cover_url']),
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status']?.toString() ?? BusinessAccountStatus.active,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

class BusinessAccountStatus {
  const BusinessAccountStatus._();

  static const pending = 'pending';
  static const active = 'active';
  static const rejected = 'rejected';
  static const suspended = 'suspended';

  static String labelFor(String? value) {
    switch (value) {
      case pending:
        return 'İncelemede';
      case active:
        return 'Aktif';
      case rejected:
        return 'Reddedildi';
      case suspended:
        return 'Askıda';
      default:
        return 'Aktif';
    }
  }
}

class BusinessBadgeLabels {
  const BusinessBadgeLabels._();

  static const business = 'İşletme';
  static const verifiedBusiness = 'Doğrulanmış İşletme';

  static String forVerified(bool isVerified) {
    return isVerified ? verifiedBusiness : business;
  }
}

class BusinessSettingsCopy {
  const BusinessSettingsCopy._();

  static String actionTitle(BusinessAccount? account) {
    return account == null ? 'İşletme hesabına geç' : 'İşletme profilini yönet';
  }

  static String actionSubtitle(BusinessAccount? account) {
    return account == null
        ? 'Mekanını veya işletmeni Match A Man’da tanıt.'
        : '${account.displayName} · ${account.displayCategory}';
  }
}

class BusinessAccountInput {
  const BusinessAccountInput({
    required this.name,
    required this.username,
    required this.category,
    this.customCategory,
    required this.city,
    required this.district,
    this.address,
    this.description,
    this.phone,
    this.website,
    this.instagram,
  });

  final String name;
  final String username;
  final String category;
  final String? customCategory;
  final String city;
  final String district;
  final String? address;
  final String? description;
  final String? phone;
  final String? website;
  final String? instagram;

  Map<String, dynamic> toCreateJson({required String ownerUserId}) {
    return {
      'owner_user_id': ownerUserId,
      'name': name.trim(),
      'username': BusinessAccountValidators.normalizeUsername(username),
      'category': category.trim(),
      if (BusinessCategories.isOther(category))
        'custom_category': BusinessAccountValidators.normalizeCustomCategory(
          customCategory,
        ),
      'city': city.trim(),
      'district': district.trim(),
      'address': _nullableTrim(address),
      'description': _nullableTrim(description),
      'phone': _nullableTrim(phone),
      'website': _nullableTrim(website),
      'instagram': BusinessAccountValidators.normalizeInstagram(instagram),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name.trim(),
      'username': BusinessAccountValidators.normalizeUsername(username),
      'category': category.trim(),
      'custom_category': BusinessCategories.isOther(category)
          ? BusinessAccountValidators.normalizeCustomCategory(customCategory)
          : null,
      'city': city.trim(),
      'district': district.trim(),
      'address': _nullableTrim(address),
      'description': _nullableTrim(description),
      'phone': _nullableTrim(phone),
      'website': _nullableTrim(website),
      'instagram': BusinessAccountValidators.normalizeInstagram(instagram),
    };
  }
}

class BusinessAccountValidators {
  const BusinessAccountValidators._();

  static String normalizeUsername(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  static String? name(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'İşletme adı gerekli.';
    if (trimmed.length < 2) return 'İşletme adı en az 2 karakter olmalı.';
    if (trimmed.length > 80) return 'İşletme adı en fazla 80 karakter olmalı.';
    return null;
  }

  static String? username(String? value) {
    final normalized = normalizeUsername(value ?? '');
    if (normalized.isEmpty) return 'İşletme kullanıcı adı gerekli.';
    if (normalized.length < 2) {
      return 'İşletme kullanıcı adı en az 2 karakter olmalı.';
    }
    if (normalized.length > 24) {
      return 'İşletme kullanıcı adı en fazla 24 karakter olmalı.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(normalized)) {
      return 'Sadece harf, rakam ve _ kullanabilirsin.';
    }
    return null;
  }

  static String? category(String? value) {
    if (!BusinessCategories.isValid(value)) return 'Kategori seçmelisin.';
    return null;
  }

  static String? customCategory({
    required String? category,
    required String? value,
  }) {
    if (!BusinessCategories.isOther(category)) return null;
    final normalized = normalizeCustomCategory(value);
    if (normalized == null) return 'İşletme türünü yazmalısın.';
    if (normalized.length < 2) {
      return 'İşletme türü en az 2 karakter olmalı.';
    }
    if (normalized.length > 40) {
      return 'İşletme türü en fazla 40 karakter olabilir.';
    }
    if (!RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜ0-9]').hasMatch(normalized)) {
      return 'İşletme türünü yazmalısın.';
    }
    return null;
  }

  static String? cityDistrict({
    required String? city,
    required String? district,
  }) {
    if ((city ?? '').trim().isEmpty || (district ?? '').trim().isEmpty) {
      return 'Şehir ve ilçe seçmelisin.';
    }
    return null;
  }

  static String? website(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    final withScheme = Uri.tryParse('https://$trimmed');
    if ((uri != null && uri.hasScheme && uri.host.contains('.')) ||
        (withScheme != null && withScheme.host.contains('.'))) {
      return null;
    }
    return 'Geçerli bir website adresi gir.';
  }

  static String? instagram(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final username = normalizeInstagram(trimmed);
    if (username == null) return null;
    if (!RegExp(r'^[a-zA-Z0-9._]{1,30}$').hasMatch(username)) {
      return 'Geçerli bir Instagram kullanıcı adı gir.';
    }
    return null;
  }

  static String? normalizeInstagram(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final withoutAt = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
    final uri = Uri.tryParse(withoutAt);
    if (uri != null && uri.host.contains('instagram.com')) {
      final segments = uri.pathSegments;
      return segments.isEmpty ? null : segments.first;
    }
    return withoutAt
        .replaceFirst('https://instagram.com/', '')
        .replaceFirst('http://instagram.com/', '')
        .split('/')
        .first;
  }

  static String? normalizeCustomCategory(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }
}

String? _nullableString(Object? value) {
  final trimmed = value?.toString().trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String _normalizeCategory(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll('Ã§', 'c')
      .replaceAll('ÄŸ', 'g')
      .replaceAll('Ä±', 'i')
      .replaceAll('Ã¶', 'o')
      .replaceAll('ÅŸ', 's')
      .replaceAll('Ã¼', 'u')
      .replaceAll('Ã‡', 'c')
      .replaceAll('Äž', 'g')
      .replaceAll('İ', 'i')
      .replaceAll('Ã–', 'o')
      .replaceAll('Åž', 's')
      .replaceAll('Ãœ', 'u');
}
