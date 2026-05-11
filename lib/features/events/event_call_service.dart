import 'package:url_launcher/url_launcher.dart';

import '../../services/supabase_service.dart';
import 'event_call_models.dart';

class EventCallService {
  const EventCallService();

  Future<EventCallContact> getEventCallContact({
    required String eventId,
    required String targetUserId,
  }) async {
    final data = await SupabaseService.client.rpc(
      'get_event_call_contact',
      params: {
        'p_event_id': eventId,
        'p_target_user_id': targetUserId,
      },
    );

    if (data is List && data.isNotEmpty) {
      return EventCallContact.fromJson(
        Map<String, dynamic>.from(data.first as Map),
      );
    }

    if (data is Map) {
      return EventCallContact.fromJson(Map<String, dynamic>.from(data));
    }

    throw StateError('Could not load call contact.');
  }

  Future<void> callPhoneNumber(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      throw StateError('This member does not have a phone number.');
    }

    final uri = Uri(scheme: 'tel', path: trimmed);
    final canLaunch = await canLaunchUrl(uri);
    if (!canLaunch) {
      throw StateError('Could not open the phone app.');
    }

    final launched = await launchUrl(uri);
    if (!launched) {
      throw StateError('Could not start the phone call.');
    }
  }
}
