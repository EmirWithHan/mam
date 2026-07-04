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
    return trimmed == other || trimmed == 'Diğer' || trimmed == 'DiÄŸer';
  }

  static List<String> allowedActivitiesForBusinessCategory({
    required String? category,
    String? customCategory,
  }) {
    final normalized = _normalizeCategory(
      isOther(category) ? customCategory : category,
    );
    if (normalized.contains('at ciftligi')) {
      return const ['At Binme', 'Doğa Gezisi', 'Outdoor', 'Kamp'];
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
      return const ['Fitness', 'CrossFit'];
    }
    if (normalized.contains('board game')) {
      return const ['Board Game', 'Sosyal Buluşma', 'Diğer'];
    }
    if (normalized.contains('kafe')) {
      return const ['Sosyal Buluşma', 'Board Game', 'Workshop', 'Diğer'];
    }
    if (normalized.contains('etkinlik mekani') ||
        normalized.contains('workshop') ||
        normalized.contains('dans')) {
      return const ['Workshop', 'Sosyal Buluşma', 'Dans', 'Diğer'];
    }
    if (normalized.contains('outdoor') ||
        normalized.contains('doga') ||
        normalized.contains('kamp') ||
        normalized.contains('trekking') ||
        normalized.contains('yuruyus')) {
      return const ['Trekking', 'Kamp', 'Outdoor', 'Bisiklet'];
    }
    if (isOther(category)) return const ['Diğer'];
    return const ['Diğer'];
  }

  static List<String> allowedEventActivities({
    required String? category,
    String? customCategory,
  }) {
    return allowedActivitiesForBusinessCategory(
      category: category,
      customCategory: customCategory,
    );
  }

  static bool canCreateActivity({
    required String? category,
    String? customCategory,
    required String activity,
  }) {
    final allowed = allowedActivitiesForBusinessCategory(
      category: category,
      customCategory: customCategory,
    );
    final normalizedActivity = _normalizeCategory(activity);
    final allowsCustom =
        isOther(category) ||
        allowed.any(
          (value) => isOther(value) || _normalizeCategory(value) == 'diger',
        );
    if (allowsCustom &&
        activity.trim().length >= 2 &&
        activity.trim().length <= 40) {
      return true;
    }
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
    this.customThemeColor,
    this.pinnedEventId,
    this.galleryUrls,
    this.isPlusActive = false,
    this.createdAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
    this.workingHours,
    this.amenities,
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
  final String? customThemeColor;
  final String? pinnedEventId;
  final List<String>? galleryUrls;
  final bool isPlusActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? workingHours;
  final List<String>? amenities;

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
      customThemeColor: _nullableString(json['custom_theme_color']),
      pinnedEventId: _nullableString(json['pinned_event_id']),
      galleryUrls: json['gallery_urls'] is List
          ? (json['gallery_urls'] as List).map((e) => e.toString()).toList()
          : null,
      isPlusActive: json['is_plus_active'] as bool? ?? false,
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      workingHours: json['working_hours'] is Map
          ? Map<String, dynamic>.from(json['working_hours'] as Map)
          : null,
      amenities: json['amenities'] is List
          ? (json['amenities'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }

  BusinessAccount copyWith({
    String? id,
    String? ownerUserId,
    String? name,
    String? username,
    String? businessTag,
    String? category,
    String? customCategory,
    String? city,
    String? district,
    String? address,
    String? description,
    String? phone,
    String? website,
    String? instagram,
    String? logoUrl,
    String? coverUrl,
    bool? isVerified,
    String? status,
    String? customThemeColor,
    String? pinnedEventId,
    List<String>? galleryUrls,
    bool? isPlusActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? workingHours,
    List<String>? amenities,
  }) {
    return BusinessAccount(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      username: username ?? this.username,
      businessTag: businessTag ?? this.businessTag,
      category: category ?? this.category,
      customCategory: customCategory ?? this.customCategory,
      city: city ?? this.city,
      district: district ?? this.district,
      address: address ?? this.address,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      instagram: instagram ?? this.instagram,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      isVerified: isVerified ?? this.isVerified,
      status: status ?? this.status,
      customThemeColor: customThemeColor ?? this.customThemeColor,
      pinnedEventId: pinnedEventId ?? this.pinnedEventId,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      isPlusActive: isPlusActive ?? this.isPlusActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      workingHours: workingHours ?? this.workingHours,
      amenities: amenities ?? this.amenities,
    );
  }
}

class BusinessPlusSubscription {
  const BusinessPlusSubscription({
    required this.id,
    required this.businessAccountId,
    this.entitlementStatus,
    this.storeSubscriptionStatus,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.autoRenewEnabled,
    this.cancellationTime,
    this.gracePeriodEnd,
    this.revocationTime,
    this.updatedAt,
  });

  final String id;
  final String businessAccountId;
  final String? entitlementStatus;
  final String? storeSubscriptionStatus;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool? autoRenewEnabled;
  final DateTime? cancellationTime;
  final DateTime? gracePeriodEnd;
  final DateTime? revocationTime;
  final DateTime? updatedAt;

  bool get hasFuturePeriodEnd {
    final end = currentPeriodEnd;
    return end != null && end.isAfter(DateTime.now());
  }

  bool get isCanceledButActive {
    return cancellationTime != null && hasFuturePeriodEnd;
  }

  factory BusinessPlusSubscription.fromJson(Map<String, dynamic> json) {
    return BusinessPlusSubscription(
      id: json['id']?.toString() ?? '',
      businessAccountId: json['business_account_id']?.toString() ?? '',
      entitlementStatus: _nullableString(json['entitlement_status']),
      storeSubscriptionStatus: _nullableString(
        json['store_subscription_status'],
      ),
      currentPeriodStart: _dateTimeFromJson(json['current_period_start']),
      currentPeriodEnd: _dateTimeFromJson(json['current_period_end']),
      autoRenewEnabled: json['auto_renew_enabled'] as bool?,
      cancellationTime: _dateTimeFromJson(json['cancellation_time']),
      gracePeriodEnd: _dateTimeFromJson(json['grace_period_end']),
      revocationTime: _dateTimeFromJson(json['revocation_time']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

class BusinessAccountStatus {
  const BusinessAccountStatus._();

  static const pending = 'pending';
  static const active = 'active';
  static const deleted = 'deleted';
  static const rejected = 'rejected';
  static const suspended = 'suspended';

  static String labelFor(String? value) {
    switch (value) {
      case pending:
        return 'İncelemede';
      case active:
        return 'Aktif';
      case deleted:
        return 'Silindi';
      case rejected:
        return 'Reddedildi';
      case suspended:
        return 'Askıda';
      default:
        return 'Aktif';
    }
  }
}

class BusinessAccountDeletionRules {
  const BusinessAccountDeletionRules._();

  static String profileAccountTypeAfterDelete() => 'user';

  static String businessStatusAfterDelete() => BusinessAccountStatus.deleted;

  static bool shouldDeactivateBusinessAccount(BusinessAccount account) {
    return account.status == BusinessAccountStatus.active ||
        account.status == BusinessAccountStatus.pending;
  }

  static bool canDeleteBusinessAccount({
    required String? currentUserId,
    required BusinessAccount account,
  }) {
    return currentUserId != null &&
        currentUserId.trim().isNotEmpty &&
        currentUserId == account.ownerUserId &&
        shouldDeactivateBusinessAccount(account);
  }

  static bool shouldCancelBusinessEvent({
    required bool isBusinessEvent,
    required String status,
    required DateTime eventDate,
    required DateTime now,
  }) {
    return isBusinessEvent &&
        status == 'active' &&
        (eventDate.isAfter(now) || eventDate.isAtSameMomentAs(now));
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

  static String actionTitle({
    required bool isBusinessAccount,
    BusinessApplication? application,
  }) {
    if (isBusinessAccount) return 'İşletme hesabını düzenle';
    if (application?.isPending == true) return 'İşletme başvurun inceleniyor.';
    return 'İşletme hesabı başvurusu yap';
  }

  static String actionSubtitle({
    required bool isBusinessAccount,
    BusinessAccount? account,
    BusinessApplication? application,
  }) {
    if (isBusinessAccount && account != null) {
      return '${account.displayName} · ${account.displayCategory}';
    }
    if (application?.isPending == true) {
      return 'Başvurun admin onayı için sırada.';
    }
    return 'İşletme bilgilerini gönder, onaydan sonra profilin yükseltilsin.';
  }
}

class BusinessIdentityRules {
  const BusinessIdentityRules._();

  static String canonicalProfileUserId(BusinessAccount account) {
    return account.ownerUserId;
  }

  static bool isSeparatelyFollowable(BusinessAccount account) {
    return false;
  }

  static bool shouldReuseExistingAccount(BusinessAccount? existing) {
    return existing != null &&
        (existing.status == BusinessAccountStatus.active ||
            existing.status == BusinessAccountStatus.pending);
  }

  static bool canFollowBusinessIdentity({
    required String? currentUserId,
    required BusinessAccount account,
  }) {
    if (currentUserId == null || currentUserId.trim().isEmpty) return false;
    if (currentUserId == account.ownerUserId) return false;
    return isSeparatelyFollowable(account);
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
    this.latitude,
    this.longitude,
    this.workingHours,
    this.amenities,
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
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? workingHours;
  final List<String>? amenities;

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
      'latitude': latitude,
      'longitude': longitude,
      'working_hours': workingHours,
      'amenities': amenities,
    };
  }

  Map<String, dynamic> toLegacyCreateJson({required String ownerUserId}) {
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
      'latitude': latitude,
      'longitude': longitude,
      'working_hours': workingHours,
      'amenities': amenities,
    };
  }

  Map<String, dynamic> toLegacyUpdateJson() {
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

class BusinessApplicationStatus {
  const BusinessApplicationStatus._();

  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
}

class BusinessApplication {
  const BusinessApplication({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.businessPhone,
    required this.fullAddress,
    this.category,
    this.customCategory,
    this.website,
    this.description,
    this.status = BusinessApplicationStatus.pending,
    this.adminNote,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String businessName;
  final String businessPhone;
  final String fullAddress;
  final String? category;
  final String? customCategory;
  final String? website;
  final String? description;
  final String status;
  final String? adminNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == BusinessApplicationStatus.pending;

  factory BusinessApplication.fromJson(Map<String, dynamic> json) {
    return BusinessApplication(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      businessPhone: json['business_phone']?.toString() ?? '',
      fullAddress: json['full_address']?.toString() ?? '',
      category: _nullableString(json['category']),
      customCategory: _nullableString(json['custom_category']),
      website: _nullableString(json['website']),
      description: _nullableString(json['description']),
      status: json['status']?.toString() ?? BusinessApplicationStatus.pending,
      adminNote: _nullableString(json['admin_note']),
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: _dateTimeFromJson(json['reviewed_at']),
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
    );
  }
}

class BusinessApplicationReviewRules {
  const BusinessApplicationReviewRules._();

  static bool canReview({
    required BusinessApplication application,
    required bool isLoading,
  }) {
    return !isLoading && application.isPending;
  }
}

class BusinessApplicationInput {
  const BusinessApplicationInput({
    required this.businessName,
    required this.businessPhone,
    required this.fullAddress,
    required this.category,
    this.customCategory,
    this.website,
    this.description,
  });

  final String businessName;
  final String businessPhone;
  final String fullAddress;
  final String category;
  final String? customCategory;
  final String? website;
  final String? description;

  Map<String, dynamic> toCreateJson({required String userId}) {
    return {
      'user_id': userId,
      'business_name': businessName.trim(),
      'business_phone': BusinessApplicationValidators.normalizeTurkishPhone(
        businessPhone,
      ),
      'full_address': fullAddress.trim(),
      'category': category.trim(),
      'custom_category': BusinessCategories.isOther(category)
          ? BusinessAccountValidators.normalizeCustomCategory(customCategory)
          : null,
      'website': _nullableTrim(website),
      'description': _nullableTrim(description),
    };
  }
}

class BusinessApplicationApprovalCategory {
  const BusinessApplicationApprovalCategory._();

  static Map<String, String?> resolve({
    required String businessName,
    String? category,
    String? customCategory,
  }) {
    final normalizedCategory = category?.trim();
    final normalizedCustom = BusinessAccountValidators.normalizeCustomCategory(
      customCategory,
    );
    if (normalizedCategory == null || normalizedCategory.isEmpty) {
      return {
        'category': BusinessCategories.other,
        'custom_category':
            BusinessAccountValidators.normalizeCustomCategory(businessName) ??
            'İşletme',
      };
    }
    if (BusinessCategories.isOther(normalizedCategory)) {
      return {
        'category': BusinessCategories.other,
        'custom_category':
            normalizedCustom ??
            BusinessAccountValidators.normalizeCustomCategory(businessName) ??
            'İşletme',
      };
    }
    return {'category': normalizedCategory, 'custom_category': null};
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

class BusinessApplicationValidators {
  const BusinessApplicationValidators._();

  static String? name(String? value) {
    if ((value ?? '').trim().isEmpty) return 'İşletme adı gerekli.';
    return null;
  }

  static String? phone(String? value) {
    if (normalizeTurkishPhone(value) != null) return null;
    return 'Geçerli bir işletme telefon numarası gir.';
  }

  static String? fullAddress(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length < 10) return 'Tam konum/adres en az 10 karakter olmalı.';
    return null;
  }

  static String? category(String? value) {
    return BusinessAccountValidators.category(value);
  }

  static String? manualCategory(String? value) {
    final normalized = BusinessAccountValidators.normalizeCustomCategory(value);
    if (normalized == null) return 'İşletme kategorisini yazmalısın.';
    if (normalized.length < 2) {
      return 'İşletme kategorisi en az 2 karakter olmalı.';
    }
    if (normalized.length > 40) {
      return 'İşletme kategorisi en fazla 40 karakter olabilir.';
    }
    if (!RegExp(r'[a-zA-ZçğıöşüÇĞİÖŞÜ0-9]').hasMatch(normalized)) {
      return 'İşletme kategorisini yazmalısın.';
    }
    return null;
  }

  static String? customCategory({
    required String? category,
    required String? value,
  }) {
    return BusinessAccountValidators.customCategory(
      category: category,
      value: value,
    );
  }

  static String? website(String? value) {
    return BusinessAccountValidators.website(value);
  }

  static String? normalizeTurkishPhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final compact = trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    String national;
    if (compact.startsWith('+90')) {
      national = digits.substring(2);
    } else if (compact.startsWith('0090')) {
      national = digits.substring(4);
    } else if (compact.startsWith('0')) {
      national = digits.substring(1);
    } else if (compact.startsWith('3') || compact.startsWith('5')) {
      national = digits;
    } else {
      return null;
    }

    if (!RegExp(r'^(3[0-9]{9}|5[0-9]{9})$').hasMatch(national)) {
      return null;
    }
    if (RegExp(r'^([0-9])\1{9}$').hasMatch(national)) return null;
    return '+90$national';
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
