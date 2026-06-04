import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import 'reports_models.dart';
import 'reports_service.dart';

class ReportsState {
  const ReportsState({
    this.loading = false,
    this.message,
    this.success = false,
  });

  final bool loading;
  final String? message;
  final bool success;

  ReportsState copyWith({
    bool? loading,
    String? message,
    bool? success,
    bool clearMessage = false,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      message: clearMessage ? null : message ?? this.message,
      success: success ?? this.success,
    );
  }
}

final reportsServiceProvider = Provider<ReportsService>((ref) {
  return const ReportsService();
});

final reportsControllerProvider =
    StateNotifierProvider<ReportsController, ReportsState>((ref) {
      return ReportsController(ref.watch(reportsServiceProvider));
    });

class ReportsController extends StateNotifier<ReportsState> {
  ReportsController(this._reportsService) : super(const ReportsState());

  final ReportsService _reportsService;

  Future<bool> submitReport(ReportInput input) async {
    state = state.copyWith(loading: true, success: false, clearMessage: true);

    try {
      await _reportsService.createReport(input);
      state = state.copyWith(loading: false, success: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        success: false,
        message: friendlyErrorMessage(error),
      );
      return false;
    }
  }
}
