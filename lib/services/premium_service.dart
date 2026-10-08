import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Commercial entitlement layer.
/// The free experience remains usable when Google Play Billing is unavailable.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const premiumMonthlyProductId = 'kadd_premium_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _initialized = false;
  bool _storeAvailable = false;
  bool _isPremium = false;
  bool _loading = false;
  String? _error;
  ProductDetails? _monthlyProduct;

  bool get isPremium => _isPremium;
  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  String? get error => _error;
  ProductDetails? get monthlyProduct => _monthlyProduct;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error) {
        _error = error.toString();
        notifyListeners();
      },
    );

    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        notifyListeners();
        return;
      }
      await _loadProducts();
      await restorePurchases();
    } catch (error) {
      _error = error.toString();
      debugPrint('PremiumService initialization failed: $error');
    }
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails({premiumMonthlyProductId});
    if (response.error != null) {
      _error = response.error!.message;
    }
    if (response.notFoundIDs.isNotEmpty) {
      _error = 'منتج Premium غير منشور في Google Play بعد.';
    }
    if (response.productDetails.isNotEmpty) {
      _monthlyProduct = response.productDetails.firstWhere(
        (product) => product.id == premiumMonthlyProductId,
        orElse: () => response.productDetails.first,
      );
    }
    notifyListeners();
  }

  Future<void> buyPremium() async {
    if (!_storeAvailable || _monthlyProduct == null) {
      _error = 'الاشتراك غير متاح حالياً. تأكد من إعداد المنتج في Google Play.';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // The generic Flutter API uses buyNonConsumable for subscriptions too;
      // Google Play determines the subscription product type from the store.
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _monthlyProduct!),
      );
    } catch (error) {
      _error = error.toString();
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != premiumMonthlyProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPremium = true;
        _error = null;
      } else if (purchase.status == PurchaseStatus.error) {
        _error = purchase.error?.message ?? 'تعذر إتمام الاشتراك.';
      } else if (purchase.status == PurchaseStatus.canceled) {
        _error = 'تم إلغاء عملية الاشتراك.';
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
