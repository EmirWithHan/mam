import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trust_score_models.dart';
import 'trust_score_service.dart';

class TrustScoreState {
  const TrustScoreState({
    this.loading = false,
    this.message,
    this.logs = const [],
  });

  final bool loading;
  final String? message;
  final List<TrustScoreLog> logs;

  TrustScoreState copyWith({
    bool? loading,
    String? message,
    List<TrustScoreLog>? logs,
    bool clearMessage = false,
  }) {
    return TrustScoreState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      logs: logs ?? this.logs,
    );
  }
}

final trustScoreServiceProvider = Provider<TrustScoreService>((ref) {
  return const TrustScoreService();
});

final trustScoreControllerProvider =
    StateNotifierProvider<TrustScoreController, TrustScoreState>((ref) {
  return TrustScoreController(ref.watch(trustScoreServiceProvider));
});

class TrustScoreController extends StateNotifier<TrustScoreState> {
  TrustScoreController(this._service) : super(const TrustScoreState());

  final TrustScoreService _service;

  Future<void> loadTrustScoreLogs() async {
    state = state.copyWith(loading: true, clearMessage: true);

    try {
      final logs = await _service.fetchMyTrustScoreLogs();
      state = TrustScoreState(logs: logs);
    } catch (error) {
      state = state.copyWith(loading: false, message: '$error');
    }
  }

  Future<void> refreshLogs() => loadTrustScoreLogs();
}
