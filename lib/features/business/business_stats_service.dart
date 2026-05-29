import '../../services/supabase_service.dart';
import 'business_stats_models.dart';

class BusinessStatsService {
  const BusinessStatsService();

  Future<BusinessStats> fetchBusinessStats(String businessId) async {
    try {
      final rows = await SupabaseService.client.rpc(
        'get_business_stats',
        params: {'p_business_id': businessId},
      );

      if (rows is List && rows.isNotEmpty) {
        return BusinessStats.fromJson(Map<String, dynamic>.from(rows.first));
      }
      if (rows is Map) {
        return BusinessStats.fromJson(Map<String, dynamic>.from(rows));
      }
      return BusinessStats.empty();
    } catch (_) {
      throw const BusinessStatsException('İstatistikler yüklenemedi.');
    }
  }
}

class BusinessStatsException implements Exception {
  const BusinessStatsException(this.message);

  final String message;

  @override
  String toString() => message;
}
