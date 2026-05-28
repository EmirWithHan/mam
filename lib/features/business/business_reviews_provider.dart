import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_reviews_models.dart';
import 'business_reviews_service.dart';

final businessReviewsServiceProvider = Provider<BusinessReviewsService>((ref) {
  return const BusinessReviewsService();
});

final businessRatingSummaryProvider =
    FutureProvider.family<BusinessRatingSummary, String>((ref, businessId) {
      return ref
          .watch(businessReviewsServiceProvider)
          .fetchRatingSummary(businessId);
    });

final businessReviewStatusProvider =
    FutureProvider.family<BusinessReviewStatus, BusinessReviewStatusArgs>((
      ref,
      args,
    ) {
      return ref
          .watch(businessReviewsServiceProvider)
          .fetchMyReviewStatus(
            eventId: args.eventId,
            businessId: args.businessId,
          );
    });

final businessReviewControllerProvider =
    StateNotifierProvider<BusinessReviewController, BusinessReviewSubmitState>((
      ref,
    ) {
      return BusinessReviewController(
        service: ref.watch(businessReviewsServiceProvider),
        ref: ref,
      );
    });

class BusinessReviewStatusArgs {
  const BusinessReviewStatusArgs({
    required this.eventId,
    required this.businessId,
  });

  final String eventId;
  final String businessId;

  @override
  bool operator ==(Object other) {
    return other is BusinessReviewStatusArgs &&
        other.eventId == eventId &&
        other.businessId == businessId;
  }

  @override
  int get hashCode => Object.hash(eventId, businessId);
}

class BusinessReviewSubmitState {
  const BusinessReviewSubmitState({this.isLoading = false, this.message});

  final bool isLoading;
  final String? message;

  BusinessReviewSubmitState copyWith({
    bool? isLoading,
    String? message,
    bool clearMessage = false,
  }) {
    return BusinessReviewSubmitState(
      isLoading: isLoading ?? this.isLoading,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class BusinessReviewController
    extends StateNotifier<BusinessReviewSubmitState> {
  BusinessReviewController({
    required BusinessReviewsService service,
    required Ref ref,
  }) : _service = service,
       _ref = ref,
       super(const BusinessReviewSubmitState());

  final BusinessReviewsService _service;
  final Ref _ref;

  Future<bool> submit(BusinessReviewInput input) async {
    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      await _service.submitReview(input);
      _ref.invalidate(
        businessReviewStatusProvider(
          BusinessReviewStatusArgs(
            eventId: input.eventId,
            businessId: input.businessId,
          ),
        ),
      );
      _ref.invalidate(businessRatingSummaryProvider(input.businessId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, message: error.toString());
      return false;
    }
  }
}
