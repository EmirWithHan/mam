import '../../core/utils/user_handle.dart';
import '../business/business_models.dart';

class EventOrganizerType {
  const EventOrganizerType._();

  static const user = 'user';
  static const business = 'business';
}

class EventCapacityBucket {
  const EventCapacityBucket._();

  static const generic = 'generic';
  static const male = 'male';
  static const female = 'female';
}

class EventCapacityRules {
  const EventCapacityRules._();

  static String? bucketFor({
    required String? gender,
    required int genericRemaining,
    required int maleRemaining,
    required int femaleRemaining,
  }) {
    final normalizedGender = _normalizeGender(gender);
    if (normalizedGender == EventCapacityBucket.male && maleRemaining > 0) {
      return EventCapacityBucket.male;
    }
    if (normalizedGender == EventCapacityBucket.female && femaleRemaining > 0) {
      return EventCapacityBucket.female;
    }
    if (genericRemaining > 0) return EventCapacityBucket.generic;
    return null;
  }

  static String? _normalizeGender(String? gender) {
    final value = gender?.trim().toLowerCase();
    if (value == 'erkek' || value == 'male') return EventCapacityBucket.male;
    if (value == 'kadın' || value == 'kadin' || value == 'female') {
      return EventCapacityBucket.female;
    }
    return null;
  }
}

class EventBusinessOrganizer {
  const EventBusinessOrganizer({
    required this.id,
    required this.name,
    required this.username,
    this.businessTag,
    this.isVerified = false,
    this.isPlusActive = false,
    this.status = BusinessAccountStatus.active,
  });

  final String id;
  final String name;
  final String username;
  final String? businessTag;
  final bool isVerified;
  final bool isPlusActive;
  final String status;

  bool get isActive => status == BusinessAccountStatus.active;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'İşletme';
    return trimmed;
  }

  String? get displayHandle => formatUserHandle(username, businessTag);

  factory EventBusinessOrganizer.fromJson(Map<String, dynamic> json) {
    return EventBusinessOrganizer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      businessTag: json['business_tag']?.toString(),
      isVerified:
          json['is_verified'] == true ||
          json['is_verified'] == 1 ||
          json['is_verified']?.toString() == 'true',
      isPlusActive:
          json['is_plus_active'] == true ||
          json['is_plus_active'] == 1 ||
          json['is_plus_active']?.toString() == 'true',
      status: json['status']?.toString() ?? BusinessAccountStatus.active,
    );
  }
}

class Event {
  const Event({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    this.sportType,
    required this.city,
    this.district,
    this.locationText,
    this.locationLat,
    this.locationLng,
    required this.eventDate,
    required this.capacityTotal,
    this.capacityMale,
    this.capacityFemale,
    this.capacityAny,
    this.approvedCount = 0,
    required this.status,
    this.isSponsored = false,
    this.sponsoredUntil,
    this.sponsoredPriority = 0,
    this.organizerType = EventOrganizerType.user,
    this.organizerUserId,
    this.organizerBusinessId,
    this.businessOrganizer,
    this.isPaid = false,
    this.priceAmount,
    this.priceCurrency = 'TRY',
    this.createdAt,
    this.updatedAt,
    this.listingExpiresAt,
    this.businessOpenTime,
    this.businessCloseTime,
    this.eventStartTime,
    this.eventEndTime,
    this.priceType,
    this.organizerEditCount = 0,
    this.organizerLastEditedAt,
    this.locationDescription,
  });

  final String id;
  final String hostId;
  final String title;
  final String? description;
  final String? sportType;
  final String city;
  final String? district;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final DateTime eventDate;
  final int capacityTotal;
  final int? capacityMale;
  final int? capacityFemale;
  final int? capacityAny;
  final int approvedCount;
  final String status;
  final bool isSponsored;
  final DateTime? sponsoredUntil;
  final int sponsoredPriority;
  final String organizerType;
  final String? organizerUserId;
  final String? organizerBusinessId;
  final EventBusinessOrganizer? businessOrganizer;
  final bool isPaid;
  final double? priceAmount;
  final String priceCurrency;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? listingExpiresAt;
  final String? businessOpenTime;
  final String? businessCloseTime;
  final String? eventStartTime;
  final String? eventEndTime;
  final String? priceType;
  final int organizerEditCount;
  final DateTime? organizerLastEditedAt;
  final String? locationDescription;

  bool isHost(String? userId) => userId != null && hostId == userId;

  bool get isPast => eventDate.isBefore(DateTime.now());

  bool get canBeEdited => editLockMessage() == null;

  bool get hasOrganizerEditRemaining => organizerEditCount < 1;

  bool isWithinEditCutoff([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return !eventDate.isAfter(reference.add(const Duration(minutes: 15)));
  }

  String? editLockMessage([DateTime? now]) {
    if (status != 'active' || isPast) return 'Bu etkinlik artık düzenlenemez.';
    if (!hasOrganizerEditRemaining) {
      return 'Bu etkinlik yalnızca bir kez düzenlenebilir.';
    }
    if (isWithinEditCutoff(now)) {
      return 'Etkinliğe 15 dakikadan az kaldığı için düzenleme kapandı.';
    }
    return null;
  }

  DateTime get attendanceWindowStart =>
      eventStartDateTime.subtract(const Duration(hours: 2));

  DateTime get attendanceWindowEnd =>
      eventStartDateTime.add(const Duration(hours: 22));

  bool isAttendanceWindowOpen([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return !reference.isBefore(attendanceWindowStart) &&
        !reference.isAfter(attendanceWindowEnd);
  }

  bool isBeforeAttendanceWindow([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return reference.isBefore(attendanceWindowStart);
  }

  bool isAfterAttendanceWindow([DateTime? now]) {
    final reference = now ?? DateTime.now();
    return reference.isAfter(attendanceWindowEnd);
  }

  DateTime get eventStartDateTime {
    final time = _parseClockTime(eventStartTime);
    if (time == null) return eventDate;
    return DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      time.hour,
      time.minute,
      time.second,
    );
  }

  DateTime? get eventEndDateTime {
    final time = _parseClockTime(eventEndTime);
    if (time == null) return null;
    final start = eventStartDateTime;
    var end = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      time.hour,
      time.minute,
      time.second,
    );
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  int get genericCapacity {
    final explicitGeneric = capacityAny;
    if (explicitGeneric != null) {
      return explicitGeneric < 0 ? 0 : explicitGeneric;
    }
    return capacityTotal < 0 ? 0 : capacityTotal;
  }

  int get maleCapacity {
    final value = capacityMale ?? 0;
    return value < 0 ? 0 : value;
  }

  int get femaleCapacity {
    final value = capacityFemale ?? 0;
    return value < 0 ? 0 : value;
  }

  int get safeCapacityTotal {
    if (capacityAny == null && capacityMale == null && capacityFemale == null) {
      return capacityTotal < 0 ? 0 : capacityTotal;
    }
    return genericCapacity + maleCapacity + femaleCapacity;
  }

  int get safeApprovedCount => approvedCount < 0 ? 0 : approvedCount;

  String get titleLabel {
    final text = title.trim();
    if (text.isEmpty) return 'Etkinlik';
    return text;
  }

  bool get isFull =>
      safeCapacityTotal > 0 && safeApprovedCount >= safeCapacityTotal;

  bool get isBusinessEvent => organizerType == EventOrganizerType.business;

  bool canOpenBusinessCheckIn(String? userId) {
    return isBusinessEvent && isHost(userId);
  }

  bool isVisibleInPublicProfileForAccountType(String accountType) {
    return !isBusinessEvent || accountType == 'business';
  }

  bool shouldCancelWhenSwitchingBackToUser(DateTime now) {
    return BusinessAccountDeletionRules.shouldCancelBusinessEvent(
      isBusinessEvent: isBusinessEvent,
      status: status,
      eventDate: eventDate,
      now: now,
    );
  }

  bool isVisibleInEventsList({String? currentUserId}) {
    if (!isBusinessEvent) return true;
    if (businessOrganizer?.isActive != true) return false;

    final expiry = listingExpiresAt;
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      return isHost(currentUserId);
    }
    return true;
  }

  bool isActiveSponsoredPlacement(DateTime now) {
    final verifiedBusiness = businessOrganizer?.isVerified == true;
    final activeBusiness = businessOrganizer?.isActive == true;
    final plusActive = businessOrganizer?.isPlusActive == true;
    if (!isSponsored ||
        !isBusinessEvent ||
        !verifiedBusiness ||
        !activeBusiness ||
        !plusActive ||
        eventDate.isBefore(now)) {
      return false;
    }
    final until = sponsoredUntil;
    return until == null || until.isAfter(now);
  }

  String get priceLabel {
    if (!isBusinessEvent) return '';
    if (priceType == 'free') return 'Ücretsiz';
    final amount = priceAmount;
    if (amount == null || amount <= 0) return 'Ücretsiz';
    final wholeAmount = amount == amount.roundToDouble();
    final formatted = wholeAmount
        ? amount.toInt().toString()
        : amount
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
    if (priceType == 'pay_at_business') {
      return '₺$formatted (İşletmede)';
    }
    return '₺$formatted';
  }

  String get priceTypeLabel {
    switch (priceType) {
      case 'free':
        return 'Ücretsiz';
      case 'pay_at_business':
        return 'İşletmede ödeme';
      default:
        return isPaid ? 'İşletmede ödeme' : 'Ücretsiz';
    }
  }

  bool get hasDescription => description?.trim().isNotEmpty == true;

  String get descriptionLabel {
    final text = description?.trim();
    if (text == null || text.isEmpty) return 'Açıklama eklenmemiş.';
    return text;
  }

  bool get hasCoordinates => locationLat != null && locationLng != null;

  bool get hasLocation {
    final text = locationText?.trim();
    return hasCoordinates || (text != null && text.isNotEmpty);
  }

  String get locationDisplayLabel {
    final text = locationText?.trim();
    if (text != null && text.isNotEmpty && !_looksLikeRawCoordinates(text)) {
      return text;
    }
    if (hasCoordinates) return 'Haritada görüntüle';
    return 'Konum bilgisi eklenmemiş.';
  }

  String get locationLabel {
    final cityValue = city.trim();
    final districtValue = district?.trim();
    if (cityValue.isEmpty && (districtValue == null || districtValue.isEmpty)) {
      return 'Konum belirtilmedi';
    }
    if (districtValue == null || districtValue.isEmpty) return cityValue;
    if (cityValue.isEmpty) return districtValue;
    return '$cityValue / $districtValue';
  }

  String get capacityLabel => formattedCapacityLabel;

  String get formattedCapacityLabel {
    return '$safeApprovedCount / $safeCapacityTotal kişi onaylandı';
  }

  String get capacityBreakdownLabel {
    return 'Karışık: $genericCapacity, Erkek: $maleCapacity, Kadın: $femaleCapacity';
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final isPaid =
        json['is_paid'] == true ||
        json['is_paid'] == 1 ||
        json['is_paid']?.toString() == 'true';
    return Event(
      id: json['id']?.toString() ?? '',
      hostId: json['host_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      sportType: json['sport_type']?.toString(),
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString(),
      locationText: json['location_text']?.toString(),
      locationLat: double.tryParse(json['location_lat']?.toString() ?? ''),
      locationLng: double.tryParse(json['location_lng']?.toString() ?? ''),
      eventDate: _dateTimeFromJson(json['event_date']) ?? DateTime.now(),
      capacityTotal: _intFromJson(json['capacity_total']),
      capacityMale: int.tryParse(
        json['male_capacity']?.toString() ??
            json['capacity_male']?.toString() ??
            '',
      ),
      capacityFemale: int.tryParse(
        json['female_capacity']?.toString() ??
            json['capacity_female']?.toString() ??
            '',
      ),
      capacityAny: int.tryParse(
        json['generic_capacity']?.toString() ??
            json['capacity_any']?.toString() ??
            '',
      ),
      approvedCount: _intFromJson(json['approved_count']),
      status: json['status']?.toString() ?? 'active',
      isSponsored:
          json['is_sponsored'] == true ||
          json['is_sponsored'] == 1 ||
          json['is_sponsored']?.toString() == 'true',
      sponsoredUntil: _dateTimeFromJson(json['sponsored_until']),
      sponsoredPriority: _intFromJson(json['sponsored_priority']),
      organizerType:
          json['organizer_type']?.toString() ?? EventOrganizerType.user,
      organizerUserId: json['organizer_user_id']?.toString(),
      organizerBusinessId: json['organizer_business_id']?.toString(),
      businessOrganizer: _businessOrganizerFromJson(json['business_accounts']),
      locationDescription: json['location_description']?.toString(),
      isPaid: isPaid,
      priceAmount: _doubleFromJson(json['price_amount']),
      priceCurrency: json['price_currency']?.toString() ?? 'TRY',
      createdAt: _dateTimeFromJson(json['created_at']),
      updatedAt: _dateTimeFromJson(json['updated_at']),
      listingExpiresAt: _dateTimeFromJson(json['listing_expires_at']),
      businessOpenTime:
          json['business_open_time']?.toString() ??
          json['event_start_time']?.toString(),
      businessCloseTime:
          json['business_close_time']?.toString() ??
          json['event_end_time']?.toString(),
      eventStartTime:
          json['event_start_time']?.toString() ??
          json['business_open_time']?.toString(),
      eventEndTime:
          json['event_end_time']?.toString() ??
          json['business_close_time']?.toString(),
      priceType:
          json['price_type']?.toString() ??
          (isPaid ? 'pay_at_business' : 'free'),
      organizerEditCount: _intFromJson(json['organizer_edit_count']),
      organizerLastEditedAt: _dateTimeFromJson(
        json['organizer_last_edited_at'],
      ),
    );
  }

  Event copyWith({
    String? id,
    String? hostId,
    String? title,
    String? description,
    String? sportType,
    String? city,
    String? district,
    String? locationText,
    double? locationLat,
    double? locationLng,
    DateTime? eventDate,
    int? capacityTotal,
    int? capacityMale,
    int? capacityFemale,
    int? capacityAny,
    int? approvedCount,
    String? status,
    bool? isSponsored,
    DateTime? sponsoredUntil,
    int? sponsoredPriority,
    String? organizerType,
    String? organizerUserId,
    String? organizerBusinessId,
    EventBusinessOrganizer? businessOrganizer,
    bool? isPaid,
    double? priceAmount,
    String? priceCurrency,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? listingExpiresAt,
    String? businessOpenTime,
    String? businessCloseTime,
    String? eventStartTime,
    String? eventEndTime,
    String? priceType,
    int? organizerEditCount,
    DateTime? organizerLastEditedAt,
    String? locationDescription,
  }) {
    return Event(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      title: title ?? this.title,
      description: description ?? this.description,
      sportType: sportType ?? this.sportType,
      city: city ?? this.city,
      district: district ?? this.district,
      locationText: locationText ?? this.locationText,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      eventDate: eventDate ?? this.eventDate,
      capacityTotal: capacityTotal ?? this.capacityTotal,
      capacityMale: capacityMale ?? this.capacityMale,
      capacityFemale: capacityFemale ?? this.capacityFemale,
      capacityAny: capacityAny ?? this.capacityAny,
      approvedCount: approvedCount ?? this.approvedCount,
      status: status ?? this.status,
      isSponsored: isSponsored ?? this.isSponsored,
      sponsoredUntil: sponsoredUntil ?? this.sponsoredUntil,
      sponsoredPriority: sponsoredPriority ?? this.sponsoredPriority,
      organizerType: organizerType ?? this.organizerType,
      organizerUserId: organizerUserId ?? this.organizerUserId,
      organizerBusinessId: organizerBusinessId ?? this.organizerBusinessId,
      businessOrganizer: businessOrganizer ?? this.businessOrganizer,
      isPaid: isPaid ?? this.isPaid,
      priceAmount: priceAmount ?? this.priceAmount,
      priceCurrency: priceCurrency ?? this.priceCurrency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      listingExpiresAt: listingExpiresAt ?? this.listingExpiresAt,
      businessOpenTime: businessOpenTime ?? this.businessOpenTime,
      businessCloseTime: businessCloseTime ?? this.businessCloseTime,
      eventStartTime: eventStartTime ?? this.eventStartTime,
      eventEndTime: eventEndTime ?? this.eventEndTime,
      priceType: priceType ?? this.priceType,
      organizerEditCount: organizerEditCount ?? this.organizerEditCount,
      organizerLastEditedAt:
          organizerLastEditedAt ?? this.organizerLastEditedAt,
      locationDescription: locationDescription ?? this.locationDescription,
    );
  }
}

List<Event> eventsWithSponsoredPlacement(List<Event> events, {DateTime? now}) {
  final referenceTime = now ?? DateTime.now();
  final activeSponsored =
      events
          .where((event) => event.isActiveSponsoredPlacement(referenceTime))
          .toList()
        ..sort((a, b) {
          final priority = b.sponsoredPriority.compareTo(a.sponsoredPriority);
          if (priority != 0) return priority;
          return a.eventDate.compareTo(b.eventDate);
        });

  if (activeSponsored.isEmpty) return events;

  final activeSponsoredIds = activeSponsored.map((event) => event.id).toSet();
  final normalEvents = events
      .where((event) => !activeSponsoredIds.contains(event.id))
      .toList();

  if (normalEvents.isEmpty) return normalEvents;

  final placed = <Event>[];
  var sponsoredIndex = 0;
  for (var index = 0; index < normalEvents.length; index += 1) {
    placed.add(normalEvents[index]);
    final shouldInsertSponsored =
        (index + 1) % 4 == 0 && sponsoredIndex < activeSponsored.length;
    if (shouldInsertSponsored) {
      placed.add(activeSponsored[sponsoredIndex]);
      sponsoredIndex += 1;
    }
  }

  return placed;
}

enum EventDateFilter { all, today, tomorrow, thisWeek, weekend, upcoming }

enum EventPriceFilter { all, free, paid }

enum EventSortOption { recommended, newest, oldest, dateAsc, dateDesc }

class EventFilters {
  const EventFilters({
    this.selectedSportType,
    this.selectedCity,
    this.dateFilter = EventDateFilter.all,
    this.priceFilter = EventPriceFilter.all,
    this.sortOption = EventSortOption.recommended,
    this.onlyAvailableSpots = false,
    this.showPastEvents = false,
  });

  final String? selectedSportType;
  final String? selectedCity;
  final EventDateFilter dateFilter;
  final EventPriceFilter priceFilter;
  final EventSortOption sortOption;
  final bool onlyAvailableSpots;
  final bool showPastEvents;

  bool get isActive {
    return selectedSportType?.trim().isNotEmpty == true ||
        selectedCity?.trim().isNotEmpty == true ||
        dateFilter != EventDateFilter.all ||
        priceFilter != EventPriceFilter.all ||
        sortOption != EventSortOption.recommended ||
        onlyAvailableSpots ||
        showPastEvents;
  }

  EventFilters copyWith({
    String? selectedSportType,
    String? selectedCity,
    EventDateFilter? dateFilter,
    EventPriceFilter? priceFilter,
    EventSortOption? sortOption,
    bool? onlyAvailableSpots,
    bool? showPastEvents,
    bool clearSportType = false,
    bool clearCity = false,
  }) {
    return EventFilters(
      selectedSportType: clearSportType
          ? null
          : selectedSportType ?? this.selectedSportType,
      selectedCity: clearCity ? null : selectedCity ?? this.selectedCity,
      dateFilter: dateFilter ?? this.dateFilter,
      priceFilter: priceFilter ?? this.priceFilter,
      sortOption: sortOption ?? this.sortOption,
      onlyAvailableSpots: onlyAvailableSpots ?? this.onlyAvailableSpots,
      showPastEvents: showPastEvents ?? this.showPastEvents,
    );
  }
}

class EventParticipationStatus {
  const EventParticipationStatus._();

  static const planned = 'planned';
  static const approved = 'approved';
  static const attended = 'attended';
  static const pending = 'pending';
  static const cancelled = 'cancelled';
  static const rejected = 'rejected';
  static const left = 'left';
  static const pendingConfirmation = 'pending_confirmation';
  static const confirmed = 'confirmed';
  static const waitlisted = 'waitlisted';
  static const checkedIn = 'checked_in';
  static const noShow = 'no_show';

  static bool isActiveApprovedParticipant(String? status) {
    return status == planned ||
        status == attended ||
        status == confirmed ||
        status == checkedIn;
  }

  static bool isApprovedParticipant(String? status) {
    return isActiveApprovedParticipant(status);
  }

  static bool hasLeftEvent(String? status) =>
      status == left || status == cancelled;

  static bool canLeaveApprovedEvent(String? status) {
    return status == planned || status == confirmed;
  }

  static bool countsAsFinalParticipant({
    required bool isBusinessEvent,
    required String? status,
  }) {
    if (isBusinessEvent) return status == confirmed || status == checkedIn;
    return isActiveApprovedParticipant(status);
  }

  static bool isPendingConfirmation(String? status) {
    return status == pendingConfirmation;
  }

  static bool isWaitlisted(String? status) => status == waitlisted;

  static bool isBusinessCheckInStatus(String? status) {
    return status == confirmed || status == checkedIn || status == noShow;
  }

  static bool canMarkBusinessAttendance({
    required bool isBusinessEvent,
    required String? status,
  }) {
    return isBusinessEvent && status == confirmed;
  }

  static String businessAttendanceLabel(String? status) {
    return switch (status) {
      checkedIn => 'Geldi',
      noShow => 'Gelmedi',
      _ => 'Bekliyor',
    };
  }
}

class EventParticipation {
  const EventParticipation({
    required this.role,
    required this.attendanceStatus,
    this.checkInToken,
    this.excuseText,
    this.excuseSubmittedAt,
    this.checkedInByUserId,
    this.onTime = false,
    this.verificationMethod,
    this.excuseStatus = 'none',
    this.cancelledAt,
    this.cancellationReason,
    this.cancellationWindow,
  });

  final String role;
  final String attendanceStatus;
  final String? checkInToken;
  final String? excuseText;
  final DateTime? excuseSubmittedAt;
  final String? checkedInByUserId;
  final bool onTime;
  final String? verificationMethod;
  final String excuseStatus;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancellationWindow;

  bool get isParticipant => role == 'participant';

  bool get hasLeftEvent {
    return EventParticipationStatus.hasLeftEvent(attendanceStatus);
  }

  bool get isActiveApprovedParticipant {
    return isParticipant &&
        EventParticipationStatus.isActiveApprovedParticipant(attendanceStatus);
  }

  bool get canLeaveApprovedEvent {
    return isParticipant &&
        EventParticipationStatus.canLeaveApprovedEvent(attendanceStatus);
  }

  bool countsAsFinalParticipant({required bool isBusinessEvent}) {
    return isParticipant &&
        EventParticipationStatus.countsAsFinalParticipant(
          isBusinessEvent: isBusinessEvent,
          status: attendanceStatus,
        );
  }

  factory EventParticipation.fromJson(Map<String, dynamic> json) {
    return EventParticipation(
      role: json['role'] as String? ?? '',
      attendanceStatus: json['attendance_status'] as String? ?? '',
      checkInToken: json['check_in_token']?.toString(),
      excuseText: json['excuse_text']?.toString(),
      excuseSubmittedAt: json['excuse_submitted_at'] != null
          ? DateTime.tryParse(json['excuse_submitted_at'].toString())
          : null,
      checkedInByUserId: json['checked_in_by_user_id']?.toString(),
      onTime: json['on_time'] as bool? ?? false,
      verificationMethod: json['verification_method']?.toString(),
      excuseStatus: json['excuse_status']?.toString() ?? 'none',
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())
          : null,
      cancellationReason: json['cancellation_reason']?.toString(),
      cancellationWindow: json['cancellation_window']?.toString(),
    );
  }

  EventParticipation copyWith({
    String? role,
    String? attendanceStatus,
    String? checkInToken,
    String? excuseText,
    DateTime? excuseSubmittedAt,
    String? checkedInByUserId,
    bool? onTime,
    String? verificationMethod,
    String? excuseStatus,
    DateTime? cancelledAt,
    String? cancellationReason,
    String? cancellationWindow,
  }) {
    return EventParticipation(
      role: role ?? this.role,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      checkInToken: checkInToken ?? this.checkInToken,
      excuseText: excuseText ?? this.excuseText,
      excuseSubmittedAt: excuseSubmittedAt ?? this.excuseSubmittedAt,
      checkedInByUserId: checkedInByUserId ?? this.checkedInByUserId,
      onTime: onTime ?? this.onTime,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      excuseStatus: excuseStatus ?? this.excuseStatus,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationWindow: cancellationWindow ?? this.cancellationWindow,
    );
  }
}

class EventPublicParticipant {
  const EventPublicParticipant({
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.city,
    this.avatarUrl,
    required this.role,
    required this.attendanceStatus,
  });

  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final String? city;
  final String? avatarUrl;
  final String role;
  final String attendanceStatus;

  bool get isHost => role == 'host';

  bool get isActiveParticipant {
    return EventPublicParticipantVisibility.isActiveParticipant(
      role: role,
      attendanceStatus: attendanceStatus,
    );
  }

  String get displayName {
    final first = firstName?.trim();
    final user = username?.trim();
    if (first != null && first.isNotEmpty) {
      return first;
    }
    if (user != null && user.isNotEmpty) return user;
    return 'Katılımcı';
  }

  String? get handleLabel {
    return formatUserHandle(username, tag);
  }

  factory EventPublicParticipant.fromJson(Map<String, dynamic> json) {
    return EventPublicParticipant(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      tag: json['tag'] as String?,
      firstName: json['first_name'] as String?,
      city: json['city'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'participant',
      attendanceStatus: json['attendance_status'] as String? ?? '',
    );
  }
}

class EventPublicParticipantVisibility {
  const EventPublicParticipantVisibility._();

  static bool canShow({
    required String role,
    required String attendanceStatus,
  }) {
    return role == 'host' ||
        isActiveParticipant(role: role, attendanceStatus: attendanceStatus);
  }

  static bool isActiveParticipant({
    required String role,
    required String attendanceStatus,
  }) {
    return role == 'participant' &&
        EventParticipationStatus.isActiveApprovedParticipant(attendanceStatus);
  }
}

class BusinessEventCheckInParticipant {
  const BusinessEventCheckInParticipant({
    required this.userId,
    this.username,
    this.tag,
    this.firstName,
    this.avatarUrl,
    required this.attendanceStatus,
    this.checkedInAt,
    this.checkInToken,
    this.excuseText,
    this.excuseSubmittedAt,
    this.excuseStatus = 'none',
  });

  final String userId;
  final String? username;
  final String? tag;
  final String? firstName;
  final String? avatarUrl;
  final String attendanceStatus;
  final DateTime? checkedInAt;
  final String? checkInToken;
  final String? excuseText;
  final DateTime? excuseSubmittedAt;
  final String excuseStatus;

  String get displayName {
    final first = firstName?.trim();
    if (first != null && first.isNotEmpty) return first;
    final user = username?.trim();
    if (user != null && user.isNotEmpty) return user;
    return 'Katılımcı';
  }

  String? get handleLabel => formatUserHandle(username, tag);

  String get statusLabel {
    if (attendanceStatus == EventParticipationStatus.cancelled) {
      if (excuseStatus == 'accepted') return 'Mazeret Kabul Edildi';
      if (excuseStatus == 'rejected') return 'Mazeret Reddedildi';
      return 'İptal Etti (Mazeretli)';
    }
    return EventParticipationStatus.businessAttendanceLabel(attendanceStatus);
  }

  bool get canMarkAttendance {
    return attendanceStatus == EventParticipationStatus.confirmed ||
        attendanceStatus == EventParticipationStatus.planned ||
        (attendanceStatus == EventParticipationStatus.cancelled &&
            excuseStatus == 'pending');
  }

  factory BusinessEventCheckInParticipant.fromJson(Map<String, dynamic> json) {
    return BusinessEventCheckInParticipant(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString(),
      tag: json['tag']?.toString(),
      firstName: json['first_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      attendanceStatus:
          json['attendance_status']?.toString() ??
          EventParticipationStatus.confirmed,
      checkedInAt: _dateTimeFromJson(json['checked_in_at']),
      checkInToken: json['check_in_token']?.toString(),
      excuseText: json['excuse_text']?.toString(),
      excuseSubmittedAt: json['excuse_submitted_at'] != null
          ? DateTime.tryParse(json['excuse_submitted_at'].toString())
          : null,
      excuseStatus: json['excuse_status']?.toString() ?? 'none',
    );
  }
}

class CreateEventInput {
  const CreateEventInput({
    required this.title,
    this.description,
    required this.sportType,
    required this.city,
    this.district,
    this.locationText,
    this.locationLat,
    this.locationLng,
    required this.eventDate,
    required this.capacityTotal,
    required this.capacityMale,
    required this.capacityFemale,
    required this.capacityAny,
    this.organizerType = EventOrganizerType.user,
    this.businessAccount,
    this.isPaid = false,
    this.priceAmount,
    this.businessOpenTime,
    this.businessCloseTime,
    this.eventStartTime,
    this.eventEndTime,
    this.priceType,
    this.locationDescription,
  });

  final String title;
  final String? description;
  final String sportType;
  final String city;
  final String? district;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final DateTime eventDate;
  final int capacityTotal;
  final int capacityMale;
  final int capacityFemale;
  final int capacityAny;
  final String organizerType;
  final BusinessAccount? businessAccount;
  final bool isPaid;
  final double? priceAmount;
  final String? businessOpenTime;
  final String? businessCloseTime;
  final String? eventStartTime;
  final String? eventEndTime;
  final String? priceType;
  final String? locationDescription;

  bool get isBusinessEvent => organizerType == EventOrganizerType.business;

  bool get hasEventLocationInfo => locationText?.trim().isNotEmpty == true;

  static bool canSelectBusinessEvent(BusinessAccount? _) {
    return false;
  }

  static bool canUseBusinessEventFields({
    required bool isBusinessAccount,
    required BusinessAccount? businessAccount,
  }) {
    return isBusinessAccount && businessAccount != null;
  }

  static String defaultOrganizerType({
    required bool isBusinessAccount,
    required BusinessAccount? businessAccount,
  }) {
    if (canUseBusinessEventFields(
      isBusinessAccount: isBusinessAccount,
      businessAccount: businessAccount,
    )) {
      return EventOrganizerType.business;
    }
    return EventOrganizerType.user;
  }

  Map<String, dynamic> toCreateJson({required String hostId}) {
    return {
      'host_id': hostId,
      'organizer_type': isBusinessEvent
          ? EventOrganizerType.business
          : EventOrganizerType.user,
      'organizer_user_id': hostId,
      if (isBusinessEvent) 'organizer_business_id': businessAccount?.id,
      'is_paid': isBusinessEvent && isPaid,
      if (isBusinessEvent && isPaid) 'price_amount': priceAmount,
      if (isBusinessEvent) 'price_currency': 'TRY',
      'title': title.trim(),
      'description': _nullableTrim(description),
      'sport_type': sportType.trim(),
      'city': city.trim(),
      'district': _nullableTrim(district),
      'location_text': _nullableTrim(locationText),
      'location_description': _nullableTrim(locationDescription),
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      'event_date': eventDate.toIso8601String(),
      'capacity_total': capacityTotal,
      'generic_capacity': capacityAny,
      'male_capacity': capacityMale,
      'female_capacity': capacityFemale,
      'status': 'active',
      if (isBusinessEvent) ...{
        'listing_expires_at': DateTime.now()
            .add(const Duration(hours: 24))
            .toIso8601String(),
        'event_start_time': eventStartTime,
        'event_end_time': eventEndTime,
        'price_type': priceType ?? (isPaid ? 'pay_at_business' : 'free'),
      },
    };
  }

  Map<String, dynamic> toLegacyCreateJson({required String hostId}) {
    return {
      'host_id': hostId,
      'organizer_type': isBusinessEvent
          ? EventOrganizerType.business
          : EventOrganizerType.user,
      'organizer_user_id': hostId,
      if (isBusinessEvent) 'organizer_business_id': businessAccount?.id,
      'is_paid': isBusinessEvent && isPaid,
      if (isBusinessEvent && isPaid) 'price_amount': priceAmount,
      if (isBusinessEvent) 'price_currency': 'TRY',
      'title': title.trim(),
      'description': _nullableTrim(description),
      'sport_type': sportType.trim(),
      'city': city.trim(),
      'district': _nullableTrim(district),
      'location_text': _nullableTrim(locationText),
      'location_description': _nullableTrim(locationDescription),
      if (locationLat != null) 'location_lat': locationLat,
      if (locationLng != null) 'location_lng': locationLng,
      'event_date': eventDate.toIso8601String(),
      'capacity_total': capacityTotal,
      'status': 'active',
    };
  }
}

class UpdateEventInput {
  const UpdateEventInput({
    required this.title,
    this.description,
    required this.sportType,
    required this.city,
    this.district,
    this.locationText,
    this.locationLat,
    this.locationLng,
    required this.eventDate,
    required this.capacityTotal,
    required this.capacityMale,
    required this.capacityFemale,
    required this.capacityAny,
    required this.isBusinessEvent,
    this.isPaid = false,
    this.priceAmount,
    this.businessOpenTime,
    this.businessCloseTime,
    this.eventStartTime,
    this.eventEndTime,
    this.priceType,
    this.locationDescription,
  });

  final String title;
  final String? description;
  final String sportType;
  final String city;
  final String? district;
  final String? locationText;
  final double? locationLat;
  final double? locationLng;
  final DateTime eventDate;
  final int capacityTotal;
  final int capacityMale;
  final int capacityFemale;
  final int capacityAny;
  final bool isBusinessEvent;
  final bool isPaid;
  final double? priceAmount;
  final String? businessOpenTime;
  final String? businessCloseTime;
  final String? eventStartTime;
  final String? eventEndTime;
  final String? priceType;
  final String? locationDescription;

  bool get hasEventLocationInfo => locationText?.trim().isNotEmpty == true;

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title.trim(),
      'description': _nullableTrim(description),
      'sport_type': sportType.trim(),
      'city': city.trim(),
      'district': _nullableTrim(district),
      'location_text': _nullableTrim(locationText),
      'location_description': _nullableTrim(locationDescription),
      'location_lat': locationLat,
      'location_lng': locationLng,
      'event_date': eventDate.toIso8601String(),
      'capacity_total': capacityTotal,
      'generic_capacity': capacityAny,
      'male_capacity': capacityMale,
      'female_capacity': capacityFemale,
      if (isBusinessEvent) ...{
        'is_paid': isPaid,
        'price_amount': isPaid ? priceAmount : null,
        'price_currency': 'TRY',
        'event_start_time': eventStartTime,
        'event_end_time': eventEndTime,
        'price_type': priceType ?? (isPaid ? 'pay_at_business' : 'free'),
      },
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toLegacyUpdateJson() {
    return {
      'title': title.trim(),
      'description': _nullableTrim(description),
      'sport_type': sportType.trim(),
      'city': city.trim(),
      'district': _nullableTrim(district),
      'location_text': _nullableTrim(locationText),
      'location_description': _nullableTrim(locationDescription),
      'location_lat': locationLat,
      'location_lng': locationLng,
      'event_date': eventDate.toIso8601String(),
      'capacity_total': capacityTotal,
      if (isBusinessEvent) ...{
        'is_paid': isPaid,
        'price_amount': isPaid ? priceAmount : null,
        'price_currency': 'TRY',
      },
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _intFromJson(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleFromJson(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

EventBusinessOrganizer? _businessOrganizerFromJson(Object? value) {
  if (value is Map) {
    return EventBusinessOrganizer.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

String? _nullableTrim(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

_ClockTime? _parseClockTime(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  final second = parts.length > 2 ? int.tryParse(parts[2].split('.').first) : 0;
  if (hour == null ||
      minute == null ||
      second == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59 ||
      second < 0 ||
      second > 59) {
    return null;
  }
  return _ClockTime(hour: hour, minute: minute, second: second);
}

class _ClockTime {
  const _ClockTime({
    required this.hour,
    required this.minute,
    required this.second,
  });

  final int hour;
  final int minute;
  final int second;
}

bool _looksLikeRawCoordinates(String value) {
  final trimmed = value.trim();
  if (trimmed == 'Mevcut konum seçildi') return true;
  if (trimmed.startsWith('Konum seçildi:')) return true;
  return RegExp(r'^-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?$').hasMatch(trimmed);
}

class MyEventItem {
  final Event event;
  final String status;

  const MyEventItem({required this.event, required this.status});

  bool get isHost => status == 'host';
  bool get isPending => status == 'pending' || status == 'pending_confirmation';
  bool get isConfirmed =>
      status == 'confirmed' ||
      status == 'planned' ||
      status == 'attended' ||
      status == 'checked_in';
}

class EventParticipantAnalytics {
  final String userId;
  final String username;
  final String firstName;
  final String? avatarUrl;
  final DateTime joinedAt;
  final DateTime? checkedInAt;
  final int messageCount;

  const EventParticipantAnalytics({
    required this.userId,
    required this.username,
    required this.firstName,
    this.avatarUrl,
    required this.joinedAt,
    this.checkedInAt,
    required this.messageCount,
  });

  factory EventParticipantAnalytics.fromJson(Map<String, dynamic> json) {
    return EventParticipantAnalytics(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      joinedAt: DateTime.parse(json['joined_at'].toString()),
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'].toString())
          : null,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName {
    if (firstName.trim().isNotEmpty) return firstName.trim();
    if (username.trim().isNotEmpty) return '@${username.trim()}';
    return 'Katılımcı';
  }
}
