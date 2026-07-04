import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/business_plus_products.dart';

class BusinessPlusPurchaseForVerification {
  const BusinessPlusPurchaseForVerification({
    required this.productId,
    required this.verificationSource,
    required this.serverVerificationData,
    required this.localVerificationData,
    required this.pendingCompletePurchase,
    required this.isRestored,
    this.purchaseId,
    this.transactionDate,
  });

  final String productId;
  final String? purchaseId;
  final String verificationSource;
  final String serverVerificationData;
  final String localVerificationData;
  final String? transactionDate;
  final bool pendingCompletePurchase;
  final bool isRestored;
}

class BusinessPlusBillingService {
  BusinessPlusBillingService({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  final InAppPurchase _inAppPurchase;

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  Future<bool> isAvailable() => _inAppPurchase.isAvailable();

  Future<ProductDetailsResponse> queryBusinessPlusProduct() {
    return _inAppPurchase.queryProductDetails({
      BusinessPlusProducts.monthlyProductId,
    });
  }

  Future<bool> buyBusinessPlus(ProductDetails productDetails) {
    final purchaseParam = PurchaseParam(productDetails: productDetails);
    return _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() => _inAppPurchase.restorePurchases();

  Future<void> verifyBusinessPlusPurchase(
    BusinessPlusPurchaseForVerification purchase,
  ) {
    throw UnimplementedError(
      'Business Plus backend purchase verification is planned for Package 3C.',
    );
  }
}
