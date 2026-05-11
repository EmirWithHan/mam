import '../../services/supabase_service.dart';
import 'trust_score_models.dart';

class TrustScoreService {
  const TrustScoreService();

  Future<List<TrustScoreLog>> fetchMyTrustScoreLogs() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be signed in to view trust score history.');
    }

    final data = await SupabaseService.client
        .from('trust_score_logs')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return data.map(TrustScoreLog.fromJson).toList();
  }
}
