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
    final dashboard = Map<String, dynamic>.from(response as Map);

    final directReportsResponse = await SupabaseService.client
        .rpc(
          'admin_list_direct_message_reports',
          params: {'p_status': null, 'p_limit': 15, 'p_offset': 0},
        )
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'admin_list_direct_message_reports', error);
          throw error;
        });
    final eventReports = (dashboard['recent_message_reports'] as List? ?? [])
        .where((row) {
          final map = Map<String, dynamic>.from(row as Map);
          return map['message_type']?.toString() != 'direct_dm';
        });
    final directReports = directReportsResponse as List? ?? [];
    final reports = <dynamic>[...eventReports, ...directReports]
      ..sort((a, b) {
        final left = Map<String, dynamic>.from(a as Map);
        final right = Map<String, dynamic>.from(b as Map);
        return right['created_at'].toString().compareTo(
          left['created_at'].toString(),
        );
      });
    dashboard['recent_message_reports'] = reports.take(15).toList();
    return dashboard;
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

  Future<void> removeReportedContent({
    required String reportType,
    required String reportId,
    String? reason,
  }) async {
    await SupabaseService.client
        .rpc(
          'remove_reported_content_as_admin',
          params: {
            'p_report_type': reportType,
            'p_report_id': reportId,
            'p_reason': reason != null && reason.trim().isNotEmpty
                ? reason.trim()
                : null,
          },
        )
        .catchError((Object error) {
          logSupabaseDebug('Admin', 'remove_reported_content_as_admin', error);
          throw error;
        });
  }
}
