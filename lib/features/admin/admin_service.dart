import '../../services/supabase_service.dart';
import '../../core/utils/error_messages.dart';

class AdminService {
  const AdminService();

  Future<bool> isCurrentUserAdmin() async {
    final response = await SupabaseService.client
        .rpc('is_current_user_admin')
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'is_current_user_admin', error);
          throw error;
        });
    return response == true;
  }

  Future<Map<String, dynamic>> fetchAdminDashboard() async {
    final response = await SupabaseService.client
        .rpc('get_admin_dashboard')
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'get_admin_dashboard', error);
          throw error;
        });
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> removeEvent(String eventId, String? reason) async {
    await SupabaseService.client
        .rpc(
          'remove_event_as_admin',
          params: {
            'p_event_id': eventId,
            'p_reason': reason != null && reason.trim().isNotEmpty
                ? reason.trim()
                : null,
          },
        )
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'remove_event_as_admin', error);
          throw error;
        });
  }

  Future<void> approveBusinessApplication(
    String applicationId,
    String? note,
  ) async {
    await SupabaseService.client
        .rpc(
          'approve_business_application',
          params: {
            'p_application_id': applicationId,
            'p_admin_note': note != null && note.trim().isNotEmpty
                ? note.trim()
                : null,
          },
        )
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'approve_business_application', error);
          throw error;
        });
  }

  Future<void> rejectBusinessApplication(
    String applicationId,
    String? note,
  ) async {
    await SupabaseService.client
        .rpc(
          'reject_business_application',
          params: {
            'p_application_id': applicationId,
            'p_admin_note': note != null && note.trim().isNotEmpty
                ? note.trim()
                : null,
          },
        )
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'reject_business_application', error);
          throw error;
        });
  }

  Future<void> resolveReport({
    required String reportType,
    required String reportId,
    required String status,
    String? reason,
  }) async {
    await SupabaseService.client
        .rpc(
          'resolve_report_as_admin',
          params: {
            'p_report_type': reportType,
            'p_report_id': reportId,
            'p_status': status,
            'p_reason': reason != null && reason.trim().isNotEmpty
                ? reason.trim()
                : null,
          },
        )
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'resolve_report_as_admin', error);
          throw error;
        });
  }
}
