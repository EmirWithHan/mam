import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    FutureProvider<List<BusinessApplication>>((ref) {
      return ref
          .watch(businessAccountServiceProvider)
          .fetchPendingApplications();
    });

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
        message: error.toString(),
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
        message: error.toString(),
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
        message: error.toString(),
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
        message: error.toString(),
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
        message: error.toString(),
      );
      return false;
    }
  }
}
