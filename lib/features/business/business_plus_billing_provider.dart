import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/business_plus_products.dart';
import 'business_plus_billing_service.dart';

enum BusinessPlusBillingStatus {
  initial,
  loading,
  available,
  unavailable,
  unsupportedPlatform,
  productNotFound,
  purchasing,
  pending,
  verificationPending,
  error,
}

class BusinessPlusBillingState {
  const BusinessPlusBillingState({
    this.status = BusinessPlusBillingStatus.initial,
    this.product,
    this.message,
    this.lastPurchase,
  });

  final BusinessPlusBillingStatus status;
  final ProductDetails? product;
  final String? message;
  final BusinessPlusPurchaseForVerification? lastPurchase;

  bool get isLoading => status == BusinessPlusBillingStatus.loading;

  bool get canStartPurchase =>
      status == BusinessPlusBillingStatus.available && product != null;

  bool get canRestore =>
      status == BusinessPlusBillingStatus.available ||
      status == BusinessPlusBillingStatus.productNotFound ||
      status == BusinessPlusBillingStatus.error;

  String? get priceLabel => product?.price;

  BusinessPlusBillingState copyWith({
    BusinessPlusBillingStatus? status,
    ProductDetails? product,
    String? message,
    BusinessPlusPurchaseForVerification? lastPurchase,
    bool clearMessage = false,
  }) {
    return BusinessPlusBillingState(
      status: status ?? this.status,
      product: product ?? this.product,
      message: clearMessage ? null : message ?? this.message,
      lastPurchase: lastPurchase ?? this.lastPurchase,
    );
  }
}

final businessPlusBillingServiceProvider = Provider<BusinessPlusBillingService>(
  (ref) {
    return BusinessPlusBillingService();
  },
);

final businessPlusBillingProvider =
    StateNotifierProvider<
      BusinessPlusBillingController,
      BusinessPlusBillingState
    >((ref) {
      return BusinessPlusBillingController(
        ref.watch(businessPlusBillingServiceProvider),
      );
    });

class BusinessPlusBillingController
    extends StateNotifier<BusinessPlusBillingState> {
  BusinessPlusBillingController(this._service)
    : super(const BusinessPlusBillingState()) {
    _purchaseSubscription = _service.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        state = state.copyWith(
          status: BusinessPlusBillingStatus.error,
          message: _friendlyError(error),
        );
      },
    );
  }

  final BusinessPlusBillingService _service;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isLoadingProduct = false;

  Future<void> loadProduct() async {
    if (_isLoadingProduct) return;
    if (!_isAndroidSupported) {
      state = state.copyWith(
        status: BusinessPlusBillingStatus.unsupportedPlatform,
        message: 'Satın alma bu platformda desteklenmiyor.',
      );
      return;
    }

    _isLoadingProduct = true;
    state = state.copyWith(
      status: BusinessPlusBillingStatus.loading,
      clearMessage: true,
    );

    try {
      final available = await _service.isAvailable();
      if (!available) {
        state = state.copyWith(
          status: BusinessPlusBillingStatus.unavailable,
          message: 'Satın alma şu anda kullanılamıyor.',
        );
        return;
      }

      final response = await _service.queryBusinessPlusProduct();
      if (response.error != null) {
        state = state.copyWith(
          status: BusinessPlusBillingStatus.error,
          message: _friendlyError(response.error!),
        );
        return;
      }

      ProductDetails? product;
      for (final details in response.productDetails) {
        if (details.id == BusinessPlusProducts.monthlyProductId) {
          product = details;
          break;
        }
      }
      if (product == null ||
          response.notFoundIDs.contains(
            BusinessPlusProducts.monthlyProductId,
          )) {
        state = state.copyWith(
          status: BusinessPlusBillingStatus.productNotFound,
          message: 'Business Plus ürünü Play Console’da bulunamadı.',
        );
        return;
      }

      state = BusinessPlusBillingState(
        status: BusinessPlusBillingStatus.available,
        product: product,
      );
    } catch (error) {
      state = state.copyWith(
        status: BusinessPlusBillingStatus.error,
        message: _friendlyError(error),
      );
    } finally {
      _isLoadingProduct = false;
    }
  }

  Future<void> startPurchase() async {
    final product = state.product;
    if (!_isAndroidSupported) {
      state = state.copyWith(
        status: BusinessPlusBillingStatus.unsupportedPlatform,
        message: 'Satın alma bu platformda desteklenmiyor.',
      );
      return;
    }
    if (product == null) {
      await loadProduct();
      if (state.product == null) return;
    }

    state = state.copyWith(
      status: BusinessPlusBillingStatus.purchasing,
      clearMessage: true,
    );

    try {
      final started = await _service.buyBusinessPlus(state.product!);
      if (!started) {
        state = state.copyWith(
          status: BusinessPlusBillingStatus.error,
          message: 'Satın alma başlatılamadı.',
        );
      }
    } catch (error) {
      state = state.copyWith(
        status: BusinessPlusBillingStatus.error,
        message: _friendlyError(error),
      );
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAndroidSupported) {
      state = state.copyWith(
        status: BusinessPlusBillingStatus.unsupportedPlatform,
        message: 'Satın alma bu platformda desteklenmiyor.',
      );
      return;
    }

    try {
      final hadProduct = state.product != null;
      final previousStatus = state.status;
      state = state.copyWith(
        status: BusinessPlusBillingStatus.loading,
        clearMessage: true,
      );
      await _service.restorePurchases();
      state = state.copyWith(
        status: hadProduct
            ? BusinessPlusBillingStatus.available
            : previousStatus,
        message: 'Geri yükleme kontrol ediliyor.',
      );
    } catch (error) {
      state = state.copyWith(
        status: BusinessPlusBillingStatus.error,
        message: _friendlyError(error),
      );
    }
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != BusinessPlusProducts.monthlyProductId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(
            status: BusinessPlusBillingStatus.pending,
            message: 'Satın alma beklemede.',
          );
          break;
        case PurchaseStatus.error:
          state = state.copyWith(
            status: BusinessPlusBillingStatus.error,
            message: _friendlyPurchaseError(purchase.error),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verificationPurchase = _verificationInputFromPurchase(purchase);
          state = state.copyWith(
            status: BusinessPlusBillingStatus.verificationPending,
            message:
                'Satın alma alındı, doğrulama bekleniyor. Plus henüz aktif edilmedi.',
            lastPurchase: verificationPurchase,
          );
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(
            status: state.product == null
                ? BusinessPlusBillingStatus.initial
                : BusinessPlusBillingStatus.available,
            message: 'Satın alma iptal edildi.',
          );
          break;
      }
    }
  }

  BusinessPlusPurchaseForVerification _verificationInputFromPurchase(
    PurchaseDetails purchase,
  ) {
    final verificationData = purchase.verificationData;
    return BusinessPlusPurchaseForVerification(
      productId: purchase.productID,
      purchaseId: purchase.purchaseID,
      verificationSource: verificationData.source,
      serverVerificationData: verificationData.serverVerificationData,
      localVerificationData: verificationData.localVerificationData,
      transactionDate: purchase.transactionDate,
      pendingCompletePurchase: purchase.pendingCompletePurchase,
      isRestored: purchase.status == PurchaseStatus.restored,
    );
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    super.dispose();
  }
}

bool get _isAndroidSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String _friendlyPurchaseError(IAPError? error) {
  if (error == null) return 'Satın alma şu anda kullanılamıyor.';
  return _friendlyError(error);
}

String _friendlyError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('cancel')) {
    return 'Satın alma iptal edildi.';
  }
  if (message.contains('notfound') || message.contains('not found')) {
    return 'Business Plus ürünü Play Console’da bulunamadı.';
  }
  if (message.contains('unavailable') || message.contains('billing')) {
    return 'Satın alma şu anda kullanılamıyor.';
  }
  return 'Satın alma şu anda tamamlanamıyor.';
}
