import '../../services/rate_limit_service.dart';
import '../../services/supabase_service.dart';
import 'reports_models.dart';

class ReportsService {
  const ReportsService({
    RateLimitService rateLimitService = const RateLimitService(),
  }) : _rateLimitService = rateLimitService;

  final RateLimitService _rateLimitService;

  Future<void> createReport(ReportInput input) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to submit a report.');
    }

    if (input.reason.value.trim().isEmpty) {
      throw StateError('Choose a report reason.');
    }

    await _rateLimitService.submitReport(targetId: input.targetId);

    await SupabaseService.client
        .from('reports')
        .insert(input.toCreateJson(reporterId: userId));
  }
}
