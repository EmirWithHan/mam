import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_models.dart';
import 'business_service.dart';

enum BusinessAccountStatusState { initial, loading, success, error }

class BusinessAccountState {
  const BusinessAccountState({
    required this.status,
    this.account,
    this.message,
  });

  const BusinessAccountState.initial()
      : status = BusinessAccountStatusState.initial,
        account = null,
        message = null;

  final BusinessAccountStatusState status;
  final BusinessAccount? account;
  final String? message;

  bool get isLoading => status == BusinessAccountStatusState.loading;

  BusinessAccountState copyWith({
    required BusinessAccountStatusState status,
    BusinessAccount? account,
    String? message,
    bool clearMessage = false,
  }) {
    return BusinessAccountState(
      status: status,
      account: account ?? this.account,
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
  return BusinessAccountController(ref.watch(businessAccountServiceProvider));
});

final publicBusinessAccountProvider =
    FutureProvider.family<BusinessAccount?, String>((ref, businessId) {
  return ref
      .watch(businessAccountServiceProvider)
      .fetchBusinessAccountById(businessId);
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
      state = BusinessAccountState(
        status: BusinessAccountStatusState.success,
        account: account,
      );
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
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
      state = BusinessAccountState(
        status: BusinessAccountStatusState.success,
        account: account,
      );
      return account;
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
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
      final account = await _service.updateBusinessAccount(id: id, input: input);
      state = BusinessAccountState(
        status: BusinessAccountStatusState.success,
        account: account,
      );
      return account;
    } catch (error) {
      state = BusinessAccountState(
        status: BusinessAccountStatusState.error,
        account: state.account,
        message: error.toString(),
      );
      return null;
    }
  }
}
