import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feedback_models.dart';
import 'feedback_service.dart';

class FeedbackState {
  const FeedbackState({
    this.isSubmitting = false,
    this.success = false,
    this.message,
  });

  final bool isSubmitting;
  final bool success;
  final String? message;

  FeedbackState copyWith({
    bool? isSubmitting,
    bool? success,
    String? message,
    bool clearMessage = false,
  }) {
    return FeedbackState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      success: success ?? this.success,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class AdminFeedbackState {
  const AdminFeedbackState({
    this.feedback = const [],
    this.isLoading = false,
    this.message,
  });

  final List<UserFeedback> feedback;
  final bool isLoading;
  final String? message;

  AdminFeedbackState copyWith({
    List<UserFeedback>? feedback,
    bool? isLoading,
    String? message,
    bool clearMessage = false,
  }) {
    return AdminFeedbackState(
      feedback: feedback ?? this.feedback,
      isLoading: isLoading ?? this.isLoading,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return const FeedbackService();
});

final feedbackControllerProvider =
    StateNotifierProvider<FeedbackController, FeedbackState>((ref) {
      return FeedbackController(ref.watch(feedbackServiceProvider));
    });

final adminFeedbackProvider =
    StateNotifierProvider<AdminFeedbackController, AdminFeedbackState>((ref) {
      return AdminFeedbackController(ref.watch(feedbackServiceProvider));
    });

class FeedbackController extends StateNotifier<FeedbackState> {
  FeedbackController(this._service) : super(const FeedbackState());

  final FeedbackService _service;

  Future<bool> submit(UserFeedbackInput input) async {
    state = state.copyWith(
      isSubmitting: true,
      success: false,
      clearMessage: true,
    );

    try {
      await _service.submitFeedback(input);
      state = const FeedbackState(
        success: true,
        message: 'Mesaj\u0131n al\u0131nd\u0131. Te\u015Fekk\u00FCr ederiz.',
      );
      return true;
    } on FeedbackException catch (error) {
      state = FeedbackState(message: error.message);
      return false;
    } catch (error) {
      state = FeedbackState(message: friendlyFeedbackErrorMessage(error));
      return false;
    }
  }
}

class AdminFeedbackController extends StateNotifier<AdminFeedbackState> {
  AdminFeedbackController(this._service) : super(const AdminFeedbackState());

  final FeedbackService _service;

  Future<void> load({bool force = false}) async {
    if (!force && state.feedback.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      final feedback = await _service.fetchLatestFeedback();
      state = AdminFeedbackState(feedback: feedback);
    } catch (_) {
      state = const AdminFeedbackState(
        message: 'Geri bildirimler yüklenemedi.',
      );
    }
  }
}
