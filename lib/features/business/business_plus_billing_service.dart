import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/business_plus_products.dart';
import '../../services/supabase_service.dart';

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

  Future<BusinessPlusVerificationResult> verifyBusinessPlusPurchase({
    required String businessId,
    required BusinessPlusPurchaseForVerification purchase,
  }) async {
    final response = await SupabaseService.client.functions.invoke(
      'verify-business-plus-purchase',
      body: {
        'business_id': businessId,
        'product_id': purchase.productId,
        'purchase_token': purchase.serverVerificationData,
        'purchase_id': purchase.purchaseId,
        'verification_source': purchase.verificationSource,
        'is_restored': purchase.isRestored,
        'pending_complete_purchase': purchase.pendingCompletePurchase,
        'platform': 'android',
      },
    );

    final data = response.data;
    if (data is! Map) {
      throw const BusinessPlusBillingException('invalid_verification_response');
    }
    if (data['error'] != null) {
      throw BusinessPlusBillingException(data['error'].toString());
    }

    return BusinessPlusVerificationResult.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _inAppPurchase.completePurchase(purchase);
  }
}

class BusinessPlusVerificationResult {
  const BusinessPlusVerificationResult({
    required this.verified,
    required this.active,
    required this.entitlementStatus,
    required this.subscriptionState,
    required this.message,
    required this.acknowledged,
  });

  final bool verified;
  final bool active;
  final String? entitlementStatus;
  final String? subscriptionState;
  final String message;
  final bool acknowledged;

  factory BusinessPlusVerificationResult.fromJson(Map<String, dynamic> json) {
    return BusinessPlusVerificationResult(
      verified: json['verified'] == true,
      active: json['active'] == true,
      entitlementStatus: json['entitlement_status']?.toString(),
      subscriptionState: json['subscription_state']?.toString(),
      message:
          json['message']?.toString() ?? 'Satın alma doğrulaması tamamlandı.',
      acknowledged: json['acknowledged'] == true,
    );
  }
}

class BusinessPlusBillingException implements Exception {
  const BusinessPlusBillingException(this.code);

  final String code;

  @override
  String toString() => code;
}
