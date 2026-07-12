import 'package:flutter/foundation.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import '../../services/rate_limit_service.dart';
import '../../services/supabase_service.dart';
import '../reports/blocks_service.dart';
import '../profile/public_profile_service.dart';
import 'events_models.dart';

class EventsService {
  const EventsService({
    BlocksService blocksService = const BlocksService(),
    RateLimitService rateLimitService = const RateLimitService(),
  }) : _blocksService = blocksService,
       _rateLimitService = rateLimitService;

  final BlocksService _blocksService;
  final RateLimitService _rateLimitService;

  Future<List<Event>> fetchEvents({
    int limit = SupabasePageSizes.events,
    int offset = 0,
  }) async {
    try {
      final data = await SupabaseService.client
          .from('events')
          .select(_eventSelect)
          .inFilter('status', ['active', 'completed'])
          .order('event_date')
          .range(offset, offset + limit - 1);
      final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      return data
          .map(Event.fromJson)
          .where((event) => !blockedUserIds.contains(event.hostId))
          .where(
            (event) =>
                event.isVisibleInEventsList(currentUserId: currentUserId),
          )
          .toList();
    } catch (error) {
      if (_isMissingCapacitySchema(error)) {
        return _fetchEventsLegacy(limit: limit, offset: offset);
      }
      logSupabaseDebug('Events', 'fetchEvents', error);
      rethrow;
    }
  }

  Future<Event> fetchEventById(String eventId) async {
    try {
      final data = await SupabaseService.client
          .from('events')
          .select(_eventSelect)
          .eq('id', eventId)
          .single();

      return Event.fromJson(data);
    } catch (error) {
      if (_isMissingCapacitySchema(error)) {
        return _fetchEventByIdLegacy(eventId);
      }
      logSupabaseDebug('Events', 'fetchEventById', error);
      rethrow;
    }
  }

  Future<List<Event>> _fetchEventsLegacy({
    required int limit,
    required int offset,
  }) async {
    final data = await SupabaseService.client
        .from('events')
        .select(_legacyEventSelect)
        .inFilter('status', ['active', 'completed'])
        .order('event_date')
        .range(offset, offset + limit - 1);
    final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    return data
        .map(Event.fromJson)
        .where((event) => !blockedUserIds.contains(event.hostId))
        .where(
          (event) => event.isVisibleInEventsList(currentUserId: currentUserId),
        )
        .toList();
  }

  Future<Event> _fetchEventByIdLegacy(String eventId) async {
    final data = await SupabaseService.client
        .from('events')
        .select(_legacyEventSelect)
        .eq('id', eventId)
        .single();

    return Event.fromJson(data);
  }

  Future<Event> createEvent(CreateEventInput input) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to create an event.');
    }
    if (!input.hasEventLocationInfo) {
      throw StateError('Etkinlik konumunu yazmalısın.');
    }
    if (input.capacityTotal < 1) {
      throw StateError('En az bir kontenjan seçmelisin.');
    }

    _ensureWithinEventCreationHorizon(
      input.eventDate,
      isBusinessPlusEvent:
          input.isBusinessEvent && input.businessAccount?.isPlusActive == true,
    );

    await _rateLimitService.createEvent(isBusinessEvent: input.isBusinessEvent);

    try {
      final data = await SupabaseService.client
          .from('events')
          .insert(input.toCreateJson(hostId: userId))
          .select(_eventSelect)
          .single();

      return Event.fromJson(data);
    } catch (error) {
      if (_isMissingCapacitySchema(error)) {
        final data = await SupabaseService.client
            .from('events')
            .insert(input.toLegacyCreateJson(hostId: userId))
            .select(_legacyEventSelect)
            .single();

        return Event.fromJson(data);
      }
      logSupabaseDebug('Events', 'createEvent', error);
      rethrow;
    }
  }

  Future<Event> updateEvent({
    required String eventId,
    required UpdateEventInput input,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to update an event.');
    }
    if (!input.hasEventLocationInfo) {
      throw StateError('Etkinlik konumunu yazmalÄ±sÄ±n.');
    }

    if (input.capacityTotal < 1) {
      throw StateError('En az bir kontenjan seçmelisin.');
    }

    final existingEvent = await fetchEventById(eventId);
    if (!existingEvent.isHost(userId)) {
      throw StateError('Bu etkinliÄŸi sadece ev sahibi dÃ¼zenleyebilir.');
    }
    if (!existingEvent.canBeEdited) {
      throw StateError('Bu etkinlik artÄ±k dÃ¼zenlenemez.');
    }
    _ensureWithinEventCreationHorizon(
      input.eventDate,
      isBusinessPlusEvent:
          existingEvent.isBusinessEvent &&
          existingEvent.businessOrganizer?.isPlusActive == true,
      existingEventDate: existingEvent.eventDate,
    );
    final occupied = await fetchCapacityBucketCounts(eventId);
    if (input.capacityAny < (occupied[EventCapacityBucket.generic] ?? 0) ||
        input.capacityMale < (occupied[EventCapacityBucket.male] ?? 0) ||
        input.capacityFemale < (occupied[EventCapacityBucket.female] ?? 0)) {
      throw StateError('Kontenjan, mevcut katılımcı sayısının altına düşemez.');
    }

    try {
      final data = await SupabaseService.client
          .from('events')
          .update(input.toUpdateJson())
          .eq('id', eventId)
          .eq('host_id', userId)
          .select(_eventSelect)
          .single();

      return Event.fromJson(data);
    } catch (error) {
      if (_isMissingCapacitySchema(error)) {
        final data = await SupabaseService.client
            .from('events')
            .update(input.toLegacyUpdateJson())
            .eq('id', eventId)
            .eq('host_id', userId)
            .select(_legacyEventSelect)
            .single();

        return Event.fromJson(data);
      }
      logSupabaseDebug('Events', 'updateEvent', error);
      rethrow;
    }
  }

  Future<void> requestToJoinEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to request to join an event.');
    }

    final event = await fetchEventById(eventId);
    if (event.isPast) {
      throw StateError('Bu etkinlik geçmişte kaldı.');
    }
    if (event.isFull) {
      throw StateError('Bu etkinlik şu anda dolu.');
    }

    await _rateLimitService.eventJoinRequest(eventId: eventId);

    if (event.isBusinessEvent) {
      await SupabaseService.client.rpc(
        'reserve_business_event_participation',
        params: {'p_event_id': eventId},
      );
    } else {
      await SupabaseService.client.rpc(
        'request_event_join',
        params: {'p_event_id': eventId},
      );
    }
  }

  Future<List<MyEventItem>> fetchMyEvents() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to view your events.');
    }

    try {
      final participantRows = await SupabaseService.client
          .from('event_participants')
          .select('event_id, attendance_status')
          .eq('user_id', userId);

      final eventStatuses = <String, String>{};
      for (final row in participantRows) {
        final json = Map<String, dynamic>.from(row);
        final eventId = json['event_id'] as String?;
        final status = json['attendance_status'] as String?;
        if (eventId != null && status != null) {
          eventStatuses[eventId] = status;
        }
      }

      final requestRows = await SupabaseService.client
          .from('event_join_requests')
          .select('event_id, status')
          .eq('user_id', userId);

      for (final row in requestRows) {
        final json = Map<String, dynamic>.from(row);
        final eventId = json['event_id'] as String?;
        final status = json['status'] as String?;
        if (eventId != null &&
            status != null &&
            !eventStatuses.containsKey(eventId)) {
          eventStatuses[eventId] = status;
        }
      }

      final eventIds = eventStatuses.keys.toList();

      final hostedRows = await SupabaseService.client
          .from('events')
          .select(_eventSelect)
          .eq('host_id', userId);

      final hostedEvents = hostedRows
          .map((row) => Event.fromJson(row))
          .toList();
      final hostedIds = hostedEvents.map((e) => e.id).toSet();

      final otherEvents = <Event>[];
      if (eventIds.isNotEmpty) {
        final otherRows = await SupabaseService.client
            .from('events')
            .select(_eventSelect)
            .inFilter('id', eventIds);
        otherEvents.addAll(
          otherRows
              .map((row) => Event.fromJson(row))
              .where((e) => !hostedIds.contains(e.id)),
        );
      }

      final allEvents = <MyEventItem>[];
      for (final e in hostedEvents) {
        allEvents.add(MyEventItem(event: e, status: 'host'));
      }
      for (final e in otherEvents) {
        allEvents.add(
          MyEventItem(event: e, status: eventStatuses[e.id] ?? 'pending'),
        );
      }
      allEvents.sort((a, b) => b.event.eventDate.compareTo(a.event.eventDate));
      return allEvents;
    } catch (_) {
      final participantRows = await SupabaseService.client
          .from('event_participants')
          .select('event_id, attendance_status')
          .eq('user_id', userId);

      final eventStatuses = <String, String>{};
      for (final row in participantRows) {
        final json = Map<String, dynamic>.from(row);
        final eventId = json['event_id'] as String?;
        final status = json['attendance_status'] as String?;
        if (eventId != null && status != null) {
          eventStatuses[eventId] = status;
        }
      }

      final requestRows = await SupabaseService.client
          .from('event_join_requests')
          .select('event_id, status')
          .eq('user_id', userId);

      for (final row in requestRows) {
        final json = Map<String, dynamic>.from(row);
        final eventId = json['event_id'] as String?;
        final status = json['status'] as String?;
        if (eventId != null &&
            status != null &&
            !eventStatuses.containsKey(eventId)) {
          eventStatuses[eventId] = status;
        }
      }

      final eventIds = eventStatuses.keys.toList();

      final hostedRows = await SupabaseService.client
          .from('events')
          .select(_legacyEventSelect)
          .eq('host_id', userId);

      final hostedEvents = hostedRows
          .map((row) => Event.fromJson(row))
          .toList();
      final hostedIds = hostedEvents.map((e) => e.id).toSet();

      final otherEvents = <Event>[];
      if (eventIds.isNotEmpty) {
        final otherRows = await SupabaseService.client
            .from('events')
            .select(_legacyEventSelect)
            .inFilter('id', eventIds);
        otherEvents.addAll(
          otherRows
              .map((row) => Event.fromJson(row))
              .where((e) => !hostedIds.contains(e.id)),
        );
      }

      final allEvents = <MyEventItem>[];
      for (final e in hostedEvents) {
        allEvents.add(MyEventItem(event: e, status: 'host'));
      }
      for (final e in otherEvents) {
        allEvents.add(
          MyEventItem(event: e, status: eventStatuses[e.id] ?? 'pending'),
        );
      }
      allEvents.sort((a, b) => b.event.eventDate.compareTo(a.event.eventDate));
      return allEvents;
    }
  }

  Future<Map<String, int>> fetchCapacityBucketCounts(String eventId) async {
    final counts = <String, int>{
      EventCapacityBucket.generic: 0,
      EventCapacityBucket.male: 0,
      EventCapacityBucket.female: 0,
    };

    final rows = await SupabaseService.client
        .from('event_participants')
        .select('capacity_bucket')
        .eq('event_id', eventId)
        .eq('role', 'participant')
        .inFilter('attendance_status', [
          EventParticipationStatus.planned,
          EventParticipationStatus.attended,
          EventParticipationStatus.confirmed,
          EventParticipationStatus.checkedIn,
        ])
        .catchError((Object error) {
          if (_isMissingCapacitySchema(error)) return const [];
          throw error;
        });

    for (final row in rows) {
      final bucket = row['capacity_bucket']?.toString();
      if (bucket == EventCapacityBucket.male ||
          bucket == EventCapacityBucket.female) {
        counts[bucket!] = (counts[bucket] ?? 0) + 1;
      } else {
        counts[EventCapacityBucket.generic] =
            (counts[EventCapacityBucket.generic] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> confirmMyBusinessParticipation(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to confirm participation.');
    }

    await SupabaseService.client.rpc(
      'confirm_business_event_participation',
      params: {'p_event_id': eventId},
    );
  }

  Future<String?> fetchMyAttendanceStatus(String eventId) async {
    final participation = await fetchMyParticipation(eventId);
    return participation?.attendanceStatus;
  }

  Future<EventParticipation?> fetchMyParticipation(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final data = await SupabaseService.client
          .from('event_participants')
          .select(
            'role,attendance_status,check_in_token,excuse_text,excuse_submitted_at',
          )
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (data == null) return null;
      return EventParticipation.fromJson(data);
    } catch (error) {
      final message = error.toString().toLowerCase();
      final isMissingColumn =
          (message.contains('check_in_token') ||
              message.contains('excuse_text') ||
              message.contains('excuse_submitted_at')) &&
          (message.contains('column') ||
              message.contains('schema') ||
              message.contains('pgrst') ||
              message.contains('42703'));

      if (isMissingColumn) {
        final data = await SupabaseService.client
            .from('event_participants')
            .select('role,attendance_status')
            .eq('event_id', eventId)
            .eq('user_id', userId)
            .maybeSingle()
            .catchError((Object err) {
              logSupabaseDebug('Events', 'fetchMyParticipationLegacy', err);
              throw err;
            });

        if (data == null) return null;
        return EventParticipation.fromJson(data);
      }

      logSupabaseDebug('Events', 'fetchMyParticipation', error);
      rethrow;
    }
  }

  Future<Map<String, String>> fetchParticipantAttendanceStatuses(
    String eventId,
  ) async {
    final rows = await SupabaseService.client
        .from('event_participants')
        .select('user_id,role,attendance_status')
        .eq('event_id', eventId)
        .eq('role', 'participant')
        .catchError((Object error) {
          logSupabaseDebug(
            'Events',
            'fetchParticipantAttendanceStatuses',
            error,
          );
          throw error;
        });

    final statuses = <String, String>{};
    for (final row in rows) {
      final userId = row['user_id'] as String?;
      final status = row['attendance_status'] as String?;
      if (userId == null || status == null) continue;
      statuses[userId] = status;
    }

    return statuses;
  }

  Future<List<EventPublicParticipant>> fetchEventPublicParticipants(
    String eventId,
  ) async {
    final rows = await SupabaseService.client
        .rpc('get_event_public_participants', params: {'p_event_id': eventId})
        .catchError((Object error) {
          logSupabaseDebug('Events', 'get_event_public_participants', error);
          throw error;
        });

    return (rows as List<dynamic>)
        .map(
          (row) => EventPublicParticipant.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where(
          (participant) => EventPublicParticipantVisibility.canShow(
            role: participant.role,
            attendanceStatus: participant.attendanceStatus,
          ),
        )
        .toList(growable: false);
  }

  Future<List<BusinessEventCheckInParticipant>>
  fetchBusinessEventCheckInParticipants(String eventId) async {
    final rows = await SupabaseService.client.rpc(
      'get_business_event_check_in_participants',
      params: {'p_event_id': eventId},
    );

    return (rows as List<dynamic>)
        .map(
          (row) => BusinessEventCheckInParticipant.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> markBusinessEventAttendance({
    required String eventId,
    required String participantUserId,
    required String attendanceStatus,
  }) async {
    await _rateLimitService.markBusinessAttendance(
      participantUserId: participantUserId,
    );

    await SupabaseService.client.rpc(
      'mark_event_attendance',
      params: {
        'p_event_id': eventId,
        'p_participant_user_id': participantUserId,
        'p_attendance_status': attendanceStatus,
      },
    );
  }

  Future<String> verifyAndCheckInParticipant({
    required String eventId,
    required String participantUserId,
    required String token,
  }) async {
    await _rateLimitService.markBusinessAttendance(
      participantUserId: participantUserId,
    );

    final response = await SupabaseService.client.rpc(
      'verify_and_check_in_participant',
      params: {
        'p_event_id': eventId,
        'p_user_id': participantUserId,
        'p_token': token,
      },
    );
    return response.toString();
  }

  Future<void> submitExcuse({
    required String eventId,
    required String excuseText,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to submit excuses.');
    }

    await SupabaseService.client
        .from('event_participants')
        .update({
          'excuse_text': excuseText,
          'excuse_submitted_at': DateTime.now().toIso8601String(),
          'excuse_status': 'pending',
        })
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<void> cancelParticipation({
    required String eventId,
    String? excuseText,
  }) async {
    await SupabaseService.client.rpc(
      'cancel_event_participation',
      params: {'p_event_id': eventId, 'p_excuse_text': excuseText},
    );
  }

  Future<void> resolveParticipantExcuse({
    required String eventId,
    required String participantUserId,
    required String excuseStatus,
  }) async {
    await SupabaseService.client.rpc(
      'resolve_participant_excuse',
      params: {
        'p_event_id': eventId,
        'p_user_id': participantUserId,
        'p_excuse_status': excuseStatus,
      },
    );
  }

  Future<List<EventParticipantAnalytics>> fetchHostEventAnalytics(
    String eventId,
  ) async {
    final response = await SupabaseService.client.rpc(
      'get_host_event_analytics',
      params: {'p_event_id': eventId},
    );

    return (response as List<dynamic>)
        .map(
          (row) => EventParticipantAnalytics.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> leaveApprovedEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to leave events.');
    }

    await SupabaseService.client.rpc(
      'leave_approved_event',
      params: {'p_event_id': eventId},
    );
    await _applyMyTrustScoreEvent(
      eventType: 'approved_event_left',
      refId: eventId,
    );
  }

  Future<void> deleteMyEvent(String eventId) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to delete events.');
    }

    await SupabaseService.client.rpc(
      'delete_my_event',
      params: {'p_event_id': eventId},
    );
  }

  String _normalize(String value) {
    return value
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
        .replaceAll('ÃƒÂ§', 'c')
        .replaceAll('Ã„Å¸', 'g')
        .replaceAll('Ã„Â±', 'i')
        .replaceAll('ÃƒÂ¶', 'o')
        .replaceAll('Ã…Å¸', 's')
        .replaceAll('ÃƒÂ¼', 'u');
  }

  dynamic _applyDbFilters(
    dynamic query,
    EventFilters filters,
    String searchQuery,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? dbStartDate;
    DateTime? dbEndDate;

    if (!filters.showPastEvents) {
      dbStartDate = now;
    }

    switch (filters.dateFilter) {
      case EventDateFilter.all:
        break;
      case EventDateFilter.today:
        final tomorrow = today.add(const Duration(days: 1));
        final start = !filters.showPastEvents && now.isAfter(today)
            ? now
            : today;
        dbStartDate = start;
        dbEndDate = tomorrow;
        break;
      case EventDateFilter.tomorrow:
        final tomorrow = today.add(const Duration(days: 1));
        final dayAfter = today.add(const Duration(days: 2));
        dbStartDate = tomorrow;
        dbEndDate = dayAfter;
        break;
      case EventDateFilter.thisWeek:
        final end = today.add(const Duration(days: 7));
        final start = !filters.showPastEvents && now.isAfter(today)
            ? now
            : today;
        dbStartDate = start;
        dbEndDate = end;
        break;
      case EventDateFilter.weekend:
        final start = !filters.showPastEvents && now.isAfter(today)
            ? now
            : today;
        dbStartDate = start;
        break;
      case EventDateFilter.upcoming:
        dbStartDate = now;
        break;
    }

    if (dbStartDate != null) {
      query = query.gte('event_date', dbStartDate.toUtc().toIso8601String());
    }
    if (dbEndDate != null) {
      query = query.lt('event_date', dbEndDate.toUtc().toIso8601String());
    }

    if (filters.selectedSportType != null) {
      query = query.eq('sport_type', filters.selectedSportType);
    }

    if (filters.selectedCity != null) {
      query = query.eq('city', filters.selectedCity);
    }

    switch (filters.priceFilter) {
      case EventPriceFilter.all:
        break;
      case EventPriceFilter.free:
        query = query.eq('is_paid', false);
        break;
      case EventPriceFilter.paid:
        query = query.eq('is_paid', true);
        break;
    }

    if (searchQuery.trim().isNotEmpty) {
      final escapedQuery = searchQuery.trim().replaceAll(',', ' ');
      query = query.or(
        'title.ilike.%$escapedQuery%,'
        'description.ilike.%$escapedQuery%,'
        'city.ilike.%$escapedQuery%,'
        'district.ilike.%$escapedQuery%,'
        'sport_type.ilike.%$escapedQuery%,'
        'location_text.ilike.%$escapedQuery%',
      );
    }

    query = query.limit(300);

    return query;
  }

  List<Event> _applyFiltersAndSorting({
    required List<Event> events,
    required EventFilters filters,
    required String searchQuery,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var result = events.where((event) {
      if (!filters.showPastEvents && event.isPast) {
        return false;
      }

      if (searchQuery.trim().isNotEmpty) {
        final query = _normalize(searchQuery);
        final matchesSearch = [
          event.titleLabel,
          event.sportType ?? '',
          event.description ?? '',
          event.city,
          event.district ?? '',
          event.locationText ?? '',
        ].any((value) => _normalize(value).contains(query));

        if (!matchesSearch) return false;
      }

      if (filters.selectedSportType != null) {
        if (_normalize(event.sportType ?? '') !=
            _normalize(filters.selectedSportType!)) {
          return false;
        }
      }

      if (filters.selectedCity != null) {
        if (_normalize(event.city) != _normalize(filters.selectedCity!)) {
          return false;
        }
      }

      if (filters.onlyAvailableSpots &&
          event.safeApprovedCount >= event.safeCapacityTotal) {
        return false;
      }

      switch (filters.priceFilter) {
        case EventPriceFilter.all:
          break;
        case EventPriceFilter.free:
          if (event.isPaid) return false;
          break;
        case EventPriceFilter.paid:
          if (!event.isPaid) return false;
          break;
      }

      switch (filters.dateFilter) {
        case EventDateFilter.all:
          break;
        case EventDateFilter.today:
          if (event.eventDate.year != now.year ||
              event.eventDate.month != now.month ||
              event.eventDate.day != now.day) {
            return false;
          }
          break;
        case EventDateFilter.tomorrow:
          final tomorrow = today.add(const Duration(days: 1));
          if (event.eventDate.year != tomorrow.year ||
              event.eventDate.month != tomorrow.month ||
              event.eventDate.day != tomorrow.day) {
            return false;
          }
          break;
        case EventDateFilter.thisWeek:
          final end = today.add(const Duration(days: 7));
          if (event.eventDate.isBefore(today) ||
              !event.eventDate.isBefore(end)) {
            return false;
          }
          break;
        case EventDateFilter.weekend:
          final weekday = event.eventDate.weekday;
          if (weekday != DateTime.saturday && weekday != DateTime.sunday) {
            return false;
          }
          break;
        case EventDateFilter.upcoming:
          if (!event.eventDate.isAfter(now)) {
            return false;
          }
          break;
      }

      return true;
    }).toList();

    return result;
  }

  Future<List<Event>> fetchFeaturedEvents({
    int limit = SupabasePageSizes.events,
    int offset = 0,
    EventFilters filters = const EventFilters(),
    String searchQuery = '',
  }) async {
    try {
      final selectQuery = _eventSelect;
      dynamic dbQuery = SupabaseService.client
          .from('events')
          .select(selectQuery)
          .inFilter('status', ['active', 'completed']);

      dbQuery = _applyDbFilters(dbQuery, filters, searchQuery);
      final List<dynamic> data = await dbQuery;

      final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      final hostIds = data
          .map((row) => row['host_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final Map<String, int> trustScores = {};
      if (hostIds.isNotEmpty) {
        const publicProfileService = PublicProfileService();
        final previewMap = await publicProfileService
            .fetchPublicProfilePreviews(hostIds);
        for (final entry in previewMap.entries) {
          final uid = entry.key;
          final score = entry.value.trustScore ?? 50;
          trustScores[uid] = score;
        }
      }

      List<Event> eventsList = data
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row as Map)))
          .where((event) => !blockedUserIds.contains(event.hostId))
          .where(
            (event) =>
                event.isVisibleInEventsList(currentUserId: currentUserId),
          )
          .toList();

      eventsList = _applyFiltersAndSorting(
        events: eventsList,
        filters: filters,
        searchQuery: searchQuery,
      );

      if (filters.sortOption == EventSortOption.recommended) {
        final parsedEvents = eventsList.map((event) {
          final trustScore = trustScores[event.hostId] ?? 50;
          return _EventWithHostScore(event, trustScore);
        }).toList();

        final now = DateTime.now();
        parsedEvents.sort((a, b) {
          final aSponsored = a.event.isActiveSponsoredPlacement(now);
          final bSponsored = b.event.isActiveSponsoredPlacement(now);
          if (aSponsored != bSponsored) {
            return aSponsored ? -1 : 1;
          }
          if (aSponsored) {
            final aPriority = a.event.sponsoredPriority;
            final bPriority = b.event.sponsoredPriority;
            if (aPriority != bPriority) {
              return bPriority.compareTo(aPriority);
            }
          }
          if (a.hostTrustScore != b.hostTrustScore) {
            return b.hostTrustScore.compareTo(a.hostTrustScore);
          }
          final aApproved = a.event.approvedCount;
          final bApproved = b.event.approvedCount;
          return bApproved.compareTo(aApproved);
        });

        eventsList = parsedEvents.map((item) => item.event).toList();
      } else {
        switch (filters.sortOption) {
          case EventSortOption.newest:
            eventsList.sort((a, b) {
              final timeA = a.createdAt ?? a.eventDate;
              final timeB = b.createdAt ?? b.eventDate;
              return timeB.compareTo(timeA);
            });
            break;
          case EventSortOption.oldest:
            eventsList.sort((a, b) {
              final timeA = a.createdAt ?? a.eventDate;
              final timeB = b.createdAt ?? b.eventDate;
              return timeA.compareTo(timeB);
            });
            break;
          case EventSortOption.dateAsc:
            eventsList.sort((a, b) => a.eventDate.compareTo(b.eventDate));
            break;
          case EventSortOption.dateDesc:
            eventsList.sort((a, b) => b.eventDate.compareTo(a.eventDate));
            break;
          default:
            break;
        }
      }

      return eventsList.skip(offset).take(limit).toList();
    } catch (error, stackTrace) {
      debugPrint(
        '[Events] fetchFeaturedEvents failed type=${error.runtimeType} message=$error\n$stackTrace',
      );
      if (_isMissingCapacitySchema(error)) {
        return _fetchFeaturedEventsLegacy(
          limit: limit,
          offset: offset,
          filters: filters,
          searchQuery: searchQuery,
        );
      }
      logSupabaseDebug('Events', 'fetchFeaturedEvents', error);
      rethrow;
    }
  }

  Future<List<Event>> _fetchFeaturedEventsLegacy({
    required int limit,
    required int offset,
    EventFilters filters = const EventFilters(),
    String searchQuery = '',
  }) async {
    try {
      final selectQuery = _legacyEventSelect;
      dynamic dbQuery = SupabaseService.client
          .from('events')
          .select(selectQuery)
          .inFilter('status', ['active', 'completed']);

      dbQuery = _applyDbFilters(dbQuery, filters, searchQuery);
      final List<dynamic> data = await dbQuery;

      final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      final hostIds = data
          .map((row) => row['host_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final Map<String, int> trustScores = {};
      if (hostIds.isNotEmpty) {
        const publicProfileService = PublicProfileService();
        final previewMap = await publicProfileService
            .fetchPublicProfilePreviews(hostIds);
        for (final entry in previewMap.entries) {
          final uid = entry.key;
          final score = entry.value.trustScore ?? 50;
          trustScores[uid] = score;
        }
      }

      List<Event> eventsList = data
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row as Map)))
          .where((event) => !blockedUserIds.contains(event.hostId))
          .where(
            (event) =>
                event.isVisibleInEventsList(currentUserId: currentUserId),
          )
          .toList();

      eventsList = _applyFiltersAndSorting(
        events: eventsList,
        filters: filters,
        searchQuery: searchQuery,
      );

      if (filters.sortOption == EventSortOption.recommended) {
        final parsedEvents = eventsList.map((event) {
          final trustScore = trustScores[event.hostId] ?? 50;
          return _EventWithHostScore(event, trustScore);
        }).toList();

        final now = DateTime.now();
        parsedEvents.sort((a, b) {
          final aSponsored = a.event.isActiveSponsoredPlacement(now);
          final bSponsored = b.event.isActiveSponsoredPlacement(now);
          if (aSponsored != bSponsored) {
            return aSponsored ? -1 : 1;
          }
          if (aSponsored) {
            final aPriority = a.event.sponsoredPriority;
            final bPriority = b.event.sponsoredPriority;
            if (aPriority != bPriority) {
              return bPriority.compareTo(aPriority);
            }
          }
          if (a.hostTrustScore != b.hostTrustScore) {
            return b.hostTrustScore.compareTo(a.hostTrustScore);
          }
          final aApproved = a.event.approvedCount;
          final bApproved = b.event.approvedCount;
          return bApproved.compareTo(aApproved);
        });

        eventsList = parsedEvents.map((item) => item.event).toList();
      } else {
        switch (filters.sortOption) {
          case EventSortOption.newest:
            eventsList.sort((a, b) {
              final timeA = a.createdAt ?? a.eventDate;
              final timeB = b.createdAt ?? b.eventDate;
              return timeB.compareTo(timeA);
            });
            break;
          case EventSortOption.oldest:
            eventsList.sort((a, b) {
              final timeA = a.createdAt ?? a.eventDate;
              final timeB = b.createdAt ?? b.eventDate;
              return timeA.compareTo(timeB);
            });
            break;
          case EventSortOption.dateAsc:
            eventsList.sort((a, b) => a.eventDate.compareTo(b.eventDate));
            break;
          case EventSortOption.dateDesc:
            eventsList.sort((a, b) => b.eventDate.compareTo(a.eventDate));
            break;
          default:
            break;
        }
      }

      return eventsList.skip(offset).take(limit).toList();
    } catch (error, stackTrace) {
      debugPrint(
        '[Events] _fetchFeaturedEventsLegacy failed type=${error.runtimeType} message=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<List<Event>> fetchFollowingEvents({
    int limit = SupabasePageSizes.events,
    int offset = 0,
    EventFilters filters = const EventFilters(),
    String searchQuery = '',
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return [];

      final followsData = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followedIds = followsData
          .map((row) => (row as Map)['following_id']?.toString())
          .whereType<String>()
          .where((id) => id != userId)
          .toList();

      if (followedIds.isEmpty) return [];

      dynamic dbQuery = SupabaseService.client
          .from('events')
          .select(_eventSelect)
          .inFilter('status', ['active', 'completed'])
          .inFilter('host_id', followedIds);

      dbQuery = _applyDbFilters(dbQuery, filters, searchQuery);
      final List<dynamic> data = await dbQuery;

      final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      List<Event> eventsList = data
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row as Map)))
          .where((event) => !blockedUserIds.contains(event.hostId))
          .where(
            (event) =>
                event.isVisibleInEventsList(currentUserId: currentUserId),
          )
          .toList();

      eventsList = _applyFiltersAndSorting(
        events: eventsList,
        filters: filters,
        searchQuery: searchQuery,
      );

      switch (filters.sortOption) {
        case EventSortOption.recommended:
          eventsList.sort((a, b) => a.eventDate.compareTo(b.eventDate));
          break;
        case EventSortOption.newest:
          eventsList.sort((a, b) {
            final timeA = a.createdAt ?? a.eventDate;
            final timeB = b.createdAt ?? b.eventDate;
            return timeB.compareTo(timeA);
          });
          break;
        case EventSortOption.oldest:
          eventsList.sort((a, b) {
            final timeA = a.createdAt ?? a.eventDate;
            final timeB = b.createdAt ?? b.eventDate;
            return timeA.compareTo(timeB);
          });
          break;
        case EventSortOption.dateAsc:
          eventsList.sort((a, b) => a.eventDate.compareTo(b.eventDate));
          break;
        case EventSortOption.dateDesc:
          eventsList.sort((a, b) => b.eventDate.compareTo(a.eventDate));
          break;
      }

      return eventsList.skip(offset).take(limit).toList();
    } catch (error, stackTrace) {
      debugPrint(
        '[Events] fetchFollowingEvents failed type=${error.runtimeType} message=$error\n$stackTrace',
      );
      if (_isMissingCapacitySchema(error)) {
        return _fetchFollowingEventsLegacy(
          limit: limit,
          offset: offset,
          filters: filters,
          searchQuery: searchQuery,
        );
      }
      logSupabaseDebug('Events', 'fetchFollowingEvents', error);
      rethrow;
    }
  }

  Future<List<Event>> _fetchFollowingEventsLegacy({
    required int limit,
    required int offset,
    EventFilters filters = const EventFilters(),
    String searchQuery = '',
  }) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return [];

      final followsData = await SupabaseService.client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      final followedIds = followsData
          .map((row) => (row as Map)['following_id']?.toString())
          .whereType<String>()
          .where((id) => id != userId)
          .toList();

      if (followedIds.isEmpty) return [];

      dynamic dbQuery = SupabaseService.client
          .from('events')
          .select(_legacyEventSelect)
          .inFilter('status', ['active', 'completed'])
          .inFilter('host_id', followedIds);

      dbQuery = _applyDbFilters(dbQuery, filters, searchQuery);
      final List<dynamic> data = await dbQuery;

      final blockedUserIds = await _blocksService.fetchMyBlockedUserIds();
      final currentUserId = SupabaseService.client.auth.currentUser?.id;

      List<Event> eventsList = data
          .map((row) => Event.fromJson(Map<String, dynamic>.from(row as Map)))
          .where((event) => !blockedUserIds.contains(event.hostId))
          .where(
            (event) =>
                event.isVisibleInEventsList(currentUserId: currentUserId),
          )
          .toList();

      eventsList = _applyFiltersAndSorting(
        events: eventsList,
        filters: filters,
        searchQuery: searchQuery,
      );

      switch (filters.sortOption) {
        case EventSortOption.recommended:
          eventsList.sort((a, b) => a.eventDate.compareTo(b.eventDate));
          break;
        case EventSortOption.newest:
          eventsList.sort((a, b) {
            final timeA = a.createdAt ?? a.eventDate;
            final timeB = b.createdAt ?? b.eventDate;
            return timeB.compareTo(timeA);
          });
          break;
        case EventSortOption.oldest:
          eventsList.sort((a, b) {
            final timeA = a.createdAt ?? a.eventDate;
            final timeB = b.createdAt ?? b.eventDate;
            return timeA.compareTo(timeB);
          });
          break;
        case EventSortOption.dateAsc:
          eventsList.sort((a, b) => a.eventDate.compareTo(b.eventDate));
          break;
        case EventSortOption.dateDesc:
          eventsList.sort((a, b) => b.eventDate.compareTo(a.eventDate));
          break;
      }

      return eventsList.skip(offset).take(limit).toList();
    } catch (error, stackTrace) {
      debugPrint(
        '[Events] _fetchFollowingEventsLegacy failed type=${error.runtimeType} message=$error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBusinessRecommendationsData({
    int limit = 10,
  }) async {
    try {
      final rows = await SupabaseService.client
          .from('business_accounts')
          .select(
            'id, name, username, business_tag, is_verified, category, city',
          )
          .eq('status', 'active')
          .limit(limit);

      return rows.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (error) {
      logSupabaseDebug('Events', 'fetchBusinessRecommendationsData', error);
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchBusinessBoostStats(
    String businessId,
  ) async {
    final response = await SupabaseService.client.rpc(
      'get_business_boost_stats',
      params: {'p_business_account_id': businessId},
    );
    return Map<String, dynamic>.from((response as List).first as Map);
  }

  Future<bool> checkEventWasBoosted(String eventId) async {
    final data = await SupabaseService.client
        .from('business_event_boosts')
        .select('id')
        .eq('event_id', eventId)
        .maybeSingle();
    return data != null;
  }

  Future<Map<String, dynamic>> boostBusinessEvent(String eventId) async {
    final response = await SupabaseService.client.rpc(
      'boost_business_event',
      params: {'p_event_id': eventId},
    );
    return Map<String, dynamic>.from((response as List).first as Map);
  }
}

class _EventWithHostScore {
  _EventWithHostScore(this.event, this.hostTrustScore);
  final Event event;
  final int hostTrustScore;
}

const _eventSelect = '''
id,
host_id,
title,
description,
sport_type,
city,
district,
location_text,
location_description,
location_lat,
location_lng,
event_date,
capacity_total,
generic_capacity,
male_capacity,
female_capacity,
approved_count,
status,
is_sponsored,
sponsored_until,
sponsored_priority,
organizer_type,
organizer_user_id,
organizer_business_id,
is_paid,
price_amount,
price_currency,
created_at,
updated_at,
listing_expires_at,
business_open_time,
business_close_time,
event_start_time,
event_end_time,
price_type,
organizer_edit_count,
organizer_last_edited_at,
business_accounts:organizer_business_id(
  id,
  name,
  username,
  business_tag,
  is_verified,
  is_plus_active,
  status
)
''';

const _legacyEventSelect = '''
id,
host_id,
title,
description,
sport_type,
city,
district,
location_text,
location_description,
location_lat,
location_lng,
event_date,
capacity_total,
approved_count,
status,
is_sponsored,
sponsored_until,
sponsored_priority,
organizer_type,
organizer_user_id,
organizer_business_id,
is_paid,
price_amount,
price_currency,
created_at,
updated_at,
organizer_edit_count,
organizer_last_edited_at,
business_accounts:organizer_business_id(
  id,
  name,
  username,
  business_tag,
  is_verified,
  is_plus_active,
  status
)
''';
bool _isMissingCapacitySchema(dynamic error) {
  final message = error.toString().toLowerCase();
  final isMissing =
      (message.contains('generic_capacity') ||
          message.contains('male_capacity') ||
          message.contains('female_capacity') ||
          message.contains('capacity_bucket') ||
          message.contains('listing_expires_at') ||
          message.contains('business_open_time') ||
          message.contains('business_close_time') ||
          message.contains('event_start_time') ||
          message.contains('event_end_time') ||
          message.contains('price_type') ||
          message.contains('participation_type') ||
          message.contains('level') ||
          message.contains('required_equipment')) &&
      (message.contains('column') ||
          message.contains('schema') ||
          message.contains('pgrst') ||
          message.contains('42703'));
  if (isMissing) {
    debugPrint(
      '[EventsService] Fallback to legacy query due to missing columns in DB: $error',
    );
  }
  return isMissing;
}

void _ensureWithinEventCreationHorizon(
  DateTime eventDate, {
  required bool isBusinessPlusEvent,
  DateTime? existingEventDate,
}) {
  if (isBusinessPlusEvent) return;

  final maxDate = DateTime.now().add(const Duration(days: 28));
  if (!eventDate.isAfter(maxDate)) return;

  if (existingEventDate != null &&
      existingEventDate.isAfter(maxDate) &&
      !eventDate.isAfter(existingEventDate)) {
    return;
  }

  if (eventDate.isAfter(maxDate)) {
    throw StateError('Etkinlik tarihi en fazla 28 gün sonrası olabilir.');
  }
}

Future<void> _applyMyTrustScoreEvent({
  required String eventType,
  required String refId,
}) async {
  try {
    await SupabaseService.client.rpc(
      'apply_my_trust_score_event',
      params: {'p_event_type': eventType, 'p_ref_id': refId},
    );
  } catch (error) {
    debugPrint('[Events] trust score event failed: ${error.runtimeType}');
  }
}
