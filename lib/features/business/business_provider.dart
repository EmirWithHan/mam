import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_messages.dart';
import '../../core/utils/pagination.dart';
import 'business_models.dart';
import 'business_service.dart';

enum BusinessAccountStatusState { initial, loading, success, error }

class BusinessAccountState {
  const BusinessAccountState({
    required this.status,
    this.account,
    this.application,
    this.isAdmin = false,
    this.message,
  });

  const BusinessAccountState.initial()
    : status = BusinessAccountStatusState.initial,
      account = null,
      application = null,
      isAdmin = false,
      message = null;

  final BusinessAccountStatusState status;
  final BusinessAccount? account;
  final BusinessApplication? application;
  final bool isAdmin;
  final String? message;

  bool get isLoading => status == BusinessAccountStatusState.loading;

  BusinessAccountState copyWith({
    required BusinessAccountStatusState status,
    BusinessAccount? account,
    BusinessApplication? application,
    bool? isAdmin,
    String? message,
    bool clearMessage = false,
  }) {
    return BusinessAccountState(
      status: status,
      account: account ?? this.account,
      application: application ?? this.application,
      isAdmin: isAdmin ?? this.isAdmin,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final businessAccountServiceProvider = Provider<BusinessAccountService>((ref) {
  return const BusinessAccountService();
});

final myBusinessAccountProvider =
    StateNotifierProvider<BusinessAccountController, BusinessAccountState>((
      ref,
    ) {
      return BusinessAccountController(
        ref.watch(businessAccountServiceProvider),
      );
    });

final publicBusinessAccountProvider =
    FutureProvider.family<BusinessAccount?, String>((ref, businessId) {
      return ref
          .watch(businessAccountServiceProvider)
          .fetchBusinessAccountById(businessId);
    });

final pendingBusinessApplicationsProvider =
    StateNotifierProvider<
      PendingBusinessApplicationsController,
      PendingBusinessApplicationsState
    >((ref) {
      return PendingBusinessApplicationsController(
        ref.watch(businessAccountServiceProvider),
      );
    });

class PendingBusinessApplicationsState {
  const PendingBusinessApplicationsState({
    this.applications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.message,
  });

  final List<BusinessApplication> applications;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? message;

  PendingBusinessApplicationsState copyWith({
    List<BusinessApplication>? applications,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? message,
    bool clearMessage = false,
  }) {
    return PendingBusinessApplicationsState(
      applications: applications ?? this.applications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class PendingBusinessApplicationsController
    extends StateNotifier<PendingBusinessApplicationsState> {
  PendingBusinessApplicationsController(this._service)
    : super(const PendingBusinessApplicationsState());

  final BusinessAccountService _service;

  Future<void> loadInitial({bool force = false}) async {
    if (!force && state.applications.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      final applications = await _service.fetchPendingApplications();
      state = PendingBusinessApplicationsState(
        applications: applications,
        hasMore: pageHasMore(
          applications.length,
          SupabasePageSizes.adminApplications,
        ),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, message: _businessMessage(error));
    }
  }

  Future<void> refresh() => loadInitial(force: true);

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearMessage: true);

    try {
      final nextApplications = await _service.fetchPendingApplications(
        offset: state.applications.length,
      );
      state = state.copyWith(
        applications: appendUniqueByKey(
          state.applications,
          nextApplications,
          (application) => application.id,
        ),
        hasMore: pageHasMore(
          nextApplications.length,
          SupabasePageSizes.adminApplications,
        ),
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        message: _businessMessage(error),
      );
    }
  }
}

class BusinessAccountController extends StateNotifier<BusinessAccountState> {
  BusinessAccountController(this._service)
    : super(const BusinessAccountState.initial());

  final BusinessAccountService _service;

  Future<void> loadMyBusinessAccount() async {
    state = state.copyWith(
      status: BusinessAccountStatusState.loading,
      clearMessage: true,
    );

    try {
      final account = await _service.fetchMyBusinessAccount();
      final application = await _service.fetchMyLatestApplication();
      final isAdmin = await _service.isCurrentUserAdmin();
      state = BusinessAccountState(
        status: BusinessAccountStatusState.success,
        account: account,
        application: application,
        isAdmin: isAdmin,
      );
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
        application: state.application,
        isAdmin: state.isAdmin,
        message: _businessMessage(error),
      );
    }
  }

  Future<BusinessAccount?> createBusinessAccount(
    BusinessAccountInput input,
  ) async {
    state = state.copyWith(
      status: BusinessAccountStatusState.loading,
      clearMessage: true,
    );

    try {
      final account = await _service.createBusinessAccount(input);
      state = state.copyWith(
        status: BusinessAccountStatusState.success,
        account: account,
      );
      return account;
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
        application: state.application,
        isAdmin: state.isAdmin,
        message: _businessMessage(error),
      );
      return null;
    }
  }

  Future<BusinessApplication?> submitApplication(
    BusinessApplicationInput input,
  ) async {
    state = state.copyWith(
      status: BusinessAccountStatusState.loading,
      clearMessage: true,
    );

    try {
      final application = await _service.submitApplication(input);
      state = state.copyWith(
        status: BusinessAccountStatusState.success,
        application: application,
      );
      return application;
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
        application: state.application,
        isAdmin: state.isAdmin,
        message: _businessMessage(error),
      );
      return null;
    }
  }

  Future<BusinessAccount?> updateBusinessAccount({
    required String id,
    required BusinessAccountInput input,
  }) async {
    state = state.copyWith(
      status: BusinessAccountStatusState.loading,
      clearMessage: true,
    );

    try {
      final account = await _service.updateBusinessAccount(
        id: id,
        input: input,
      );
      state = state.copyWith(
        status: BusinessAccountStatusState.success,
        account: account,
      );
      return account;
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
        application: state.application,
        isAdmin: state.isAdmin,
        message: _businessMessage(error),
      );
      return null;
    }
  }

  Future<bool> deleteMyBusinessAccount() async {
    state = state.copyWith(
      status: BusinessAccountStatusState.loading,
      clearMessage: true,
    );

    try {
      await _service.deleteMyBusinessAccount();
      state = BusinessAccountState(
        status: BusinessAccountStatusState.success,
        application: state.application,
        isAdmin: state.isAdmin,
      );
      return true;
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
        application: state.application,
        isAdmin: state.isAdmin,
        message: _businessMessage(error),
      );
      return false;
    }
  }
}

String _businessMessage(Object error) {
  if (error is BusinessAccountException) return error.message;
  return friendlyErrorMessage(error);
}
