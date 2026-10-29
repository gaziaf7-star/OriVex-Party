import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:general/src/core/index.dart';
import 'package:general/src/features/payment/domain/use_case/google_pay_use_case.dart';

class PurchaseService {
  final InAppPurchase connection = InAppPurchase.instance;

  ProductDetailsResponse? result;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Purchase tokens currently being verified, so a purchase delivered twice
  /// (stream + restore, or a re-subscribed stream) is credited only once.
  final Set<String> _inFlight = {};

  /// Subscribes to the purchase stream exactly once and asks Play for any
  /// purchase that was paid for but never consumed (app killed mid-flow,
  /// backend down, ...) so it gets verified and credited now. Called when
  /// the coins page loads (the user is logged in by then). Safe to call
  /// repeatedly. Previously every coins-page load added another listener,
  /// so one purchase was sent to the backend several times.
  Future<void> init() async {
    if (_subscription != null) return;
    _subscription = connection.purchaseStream.listen(
      handlePurchaseUpdates,
      onError: (error) => Methods.printLog("⚠️ Purchase stream error: $error"),
    );
    if (!Platform.isAndroid) return;
    try {
      if (await connection.isAvailable()) {
        await connection.restorePurchases();
      }
    } catch (e) {
      Methods.printLog("⚠️ restorePurchases error: $e");
    }
  }

  Future<void> handlePurchaseUpdates(List<PurchaseDetails> detailsList) async {
    for (final purchaseDetails in detailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          Methods.safeShowToast(isLoading: true);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliver(purchaseDetails);
          break;
        case PurchaseStatus.error:
          Methods.printLog("status error: ${purchaseDetails.error?.message}");
          Methods.safeShowToast(
            message: _getErrorMessage(purchaseDetails.error),
            isError: true,
          );
          await acknowledgePurchase(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          Methods.safeShowToast(message: 'Purchase was cancelled.');
          await acknowledgePurchase(purchaseDetails);
          break;
      }
    }
  }

  /// Credits the coins on the backend FIRST and only then consumes the
  /// purchase. Consuming before the backend confirmed meant a failed
  /// verification left the user charged with no coins and no way to retry.
  /// An unconsumed purchase is redelivered by [init] next time, and
  /// Google refunds it automatically if it is never acknowledged.
  Future<void> _deliver(PurchaseDetails purchaseDetails) async {
    if (!Platform.isAndroid) {
      // iOS server verification is not implemented on the backend yet.
      await acknowledgePurchase(purchaseDetails);
      return;
    }
    final token = purchaseDetails.verificationData.serverVerificationData;
    if (!_inFlight.add(token)) return;
    try {
      final response = await di<GooglePayUseCase>()(GooglePayParam(
          purchaseToken: token, productId: purchaseDetails.productID));
      await response.fold(
        (failure) async {
          Methods.printLog(
              "🛒 [IAP] backend verification failed for ${purchaseDetails.productID}");
          // A restored purchase is a silent background retry.
          if (purchaseDetails.status != PurchaseStatus.purchased) return;
          Methods.safeShowToast(
            message: 'Payment received but coins could not be added yet. '
                'It will be retried automatically, or refunded by Google Play.',
            isError: true,
          );
        },
        (success) async {
          await _consume(purchaseDetails);
          if (purchaseDetails.status == PurchaseStatus.purchased) {
            Methods.safeShowToast(message: 'Coins added successfully');
          }
          di<FetchUserDataBloc>().add(const FetchMyDataEvent(isLoading: false));
        },
      );
    } finally {
      _inFlight.remove(token);
    }
  }

  Future<void> _consume(PurchaseDetails purchaseDetails) async {
    try {
      final billingResult = await connection
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(purchaseDetails);
      if (billingResult.responseCode != BillingResponse.ok) {
        Methods.printLog("consume_purchase error ${billingResult.debugMessage}");
      }
    } catch (e) {
      Methods.printLog("consume_purchase error $e");
    }
  }

  Future<void> acknowledgePurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    } catch (e) {
      Methods.printLog("acknowledge_purchase error $e");
    }
  }

  /// Check if the billing service is available
  Future<bool> checkAvailability() async {
    try {
      final bool available = await connection.isAvailable();
      if (!available) {
        Methods.printLog("⚠️ In-app purchase service not available");
      }
      return available;
    } catch (e) {
      Methods.printLog("⚠️ Error checking billing availability: $e");
      return false;
    }
  }

  /// Finds the loaded Play product for a backend coin package id. Play
  /// Console SKUs have been seen both as the bare id ("2") and as "coin_2".
  ProductDetails? findProduct(String coinId) {
    final products = result?.productDetails ?? const <ProductDetails>[];
    final bare = coinId.replaceFirst('coin_', '');
    return products.where((p) => p.id == coinId).firstOrNull ??
        products.where((p) => p.id.replaceFirst('coin_', '') == bare).firstOrNull;
  }

  /// Get user-friendly error message based on exception
  String _getErrorMessage(dynamic error) {
    if (error is PlatformException || error is IAPError) {
      // A Play purchase error arrives as IAPError(code: 'purchase_error',
      // message: 'BillingResponse.<name>'), so the message is the real code.
      final String code =
          error is PlatformException ? error.code : (error as IAPError).message;
      final String? message =
          error is PlatformException ? error.message : null;
      switch (code) {
        case 'storekit_duplicate_product_object':
        case 'purchase_pending':
          return 'A purchase is already in progress. Please wait.';
        case 'billing_unavailable':
        case 'service_unavailable':
        case 'BillingResponse.billingUnavailable':
        case 'BillingResponse.serviceUnavailable':
          return 'Google Play billing is not available. Please check that Google Play is enabled and up-to-date on your device.';
        case 'developer_error':
        case 'BillingResponse.developerError':
          return 'Configuration error. Please try again later.';
        case 'item_already_owned':
        case 'BillingResponse.itemAlreadyOwned':
          return 'A previous purchase of this package is still being processed. Please reopen the app and try again.';
        case 'user_canceled':
        case 'BillingResponse.userCanceled':
          return 'Purchase was cancelled.';
        default:
          return 'Purchase failed: ${message ?? code}';
      }
    }
    return 'Something went wrong. Please check that Google Play is enabled on your device and try again.';
  }

  Future<void> buyProduct(ProductDetails? product) async {
    if (product == null) {
      Methods.safeShowToast(
        message: 'This package is not available right now',
        isError: true,
      );
      return;
    }

    // Check if billing is available before attempting purchase
    final bool isAvailable = await checkAvailability();
    if (!isAvailable) {
      Methods.safeShowToast(
        message:
            'Google Play is not available on this device. Please check that Google Play is enabled and up-to-date.',
        isError: true,
      );
      return;
    }

    await init();
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      // autoConsume is off on Android so the purchase is consumed only after
      // the backend has credited the coins (see [_deliver]). StoreKit
      // requires it to stay true.
      await connection.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: !Platform.isAndroid,
      );
    } on PlatformException catch (e) {
      Methods.printLog("Purchase PlatformException: ${e.code} - ${e.message}");
      Methods.safeShowToast(
        message: _getErrorMessage(e),
        isError: true,
      );
    } catch (e) {
      Methods.printLog("Purchase error: $e");
      Methods.safeShowToast(
        message: _getErrorMessage(e),
        isError: true,
      );
    }
  }
}
