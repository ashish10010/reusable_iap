import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_iap/reusable_iap.dart';

class FakeBillingGateway implements BillingGateway {
  final StreamController<List<BillingPurchase>> _purchaseController =
      StreamController<List<BillingPurchase>>.broadcast();

  bool available = true;
  BillingQueryResult queryResult = const BillingQueryResult();
  final List<String> consumableBuys = <String>[];
  final List<String> nonConsumableBuys = <String>[];
  final List<String> completedProducts = <String>[];
  int restoreCalls = 0;

  @override
  Stream<List<BillingPurchase>> get purchaseStream => _purchaseController.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BillingQueryResult> queryProducts(
    Set<IapProductDefinition> products,
  ) async {
    return queryResult;
  }

  @override
  Future<void> buyConsumable(
    String productId, {
    bool autoConsume = true,
  }) async {
    consumableBuys.add(productId);
  }

  @override
  Future<void> buyNonConsumable(String productId) async {
    nonConsumableBuys.add(productId);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls += 1;
  }

  @override
  Future<void> completePurchase(BillingPurchase purchase) async {
    completedProducts.add(purchase.purchase.productId);
  }

  void emitPurchases(List<BillingPurchase> purchases) {
    _purchaseController.add(purchases);
  }

  Future<void> dispose() async {
    await _purchaseController.close();
  }
}

BillingProduct billingProduct(
  String id,
  IapProductType type,
) {
  return BillingProduct(
    product: IapProduct(
      id: id,
      type: type,
      title: '$id title',
      description: '$id description',
      price: '\$4.99',
      currencyCode: 'USD',
      rawPrice: 4.99,
    ),
  );
}

BillingPurchase billingPurchase(
  String productId,
  IapPurchaseStatus status, {
  bool pendingCompletePurchase = false,
  String? errorMessage,
}) {
  return BillingPurchase(
    purchase: IapPurchase(
      productId: productId,
      status: status,
      pendingCompletePurchase: pendingCompletePurchase,
      errorMessage: errorMessage,
      verificationData: const IapVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server',
        source: 'test',
      ),
    ),
  );
}

void main() {
  late FakeBillingGateway gateway;

  setUp(() {
    gateway = FakeBillingGateway();
  });

  tearDown(() async {
    await gateway.dispose();
  });

  test('initialize reflects store unavailability', () async {
    gateway.available = false;

    final service = IapService(
      config: IapConfig(
        products: {
          const IapProductDefinition.subscription('pro_monthly'),
        },
      ),
      gateway: gateway,
    );

    final initialState = await service.state.first;
    expect(initialState, service.currentState);

    await service.initialize();

    expect(service.currentState.initialized, isTrue);
    expect(service.currentState.available, isFalse);
    expect(service.currentState.error?.code, IapErrorCode.storeUnavailable);

    service.dispose();
  });

  test('loadProducts normalizes the catalog and buy routes by product type',
      () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('coins_100', IapProductType.consumable),
        billingProduct('lifetime_unlock', IapProductType.nonConsumable),
        billingProduct('pro_monthly', IapProductType.subscription),
      ],
    );

    final service = IapService(
      config: IapConfig(
        consumableIds: {'coins_100'},
        nonConsumableIds: {'lifetime_unlock'},
        subscriptionIds: {'pro_monthly'},
      ),
      gateway: gateway,
    );

    await service.initialize();
    final products = await service.loadProducts();

    expect(products, hasLength(3));
    expect(
      products
          .firstWhere((product) => product.id == 'pro_monthly')
          .isSubscription,
      isTrue,
    );

    await service.buy('coins_100');
    await service.buy('lifetime_unlock');
    await service.buy('pro_monthly');

    expect(gateway.consumableBuys, ['coins_100']);
    expect(
      gateway.nonConsumableBuys,
      ['lifetime_unlock', 'pro_monthly'],
    );

    service.dispose();
  });

  test('purchased and restored updates grant entitlements and complete purchase',
      () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('pro_monthly', IapProductType.subscription),
        billingProduct('lifetime_unlock', IapProductType.nonConsumable),
      ],
    );

    final service = IapService(
      config: IapConfig(
        subscriptionIds: {'pro_monthly'},
        nonConsumableIds: {'lifetime_unlock'},
      ),
      entitlementResolver: (purchase) {
        if (purchase.productId == 'pro_monthly' ||
            purchase.productId == 'lifetime_unlock') {
          return {'premium'};
        }
        return const <String>{};
      },
      gateway: gateway,
    );

    await service.initialize();
    await service.loadProducts();

    gateway.emitPurchases([
      billingPurchase(
        'pro_monthly',
        IapPurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
      billingPurchase(
        'lifetime_unlock',
        IapPurchaseStatus.restored,
        pendingCompletePurchase: true,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(service.hasEntitlement('premium'), isTrue);
    expect(
      service.currentState.lastPurchase?.status,
      IapPurchaseStatus.restored,
    );
    expect(
      gateway.completedProducts,
      ['pro_monthly', 'lifetime_unlock'],
    );

    service.dispose();
  });

  test('verification failure blocks entitlements and acknowledgement', () async {
    gateway.queryResult = BillingQueryResult(
      products: [
        billingProduct('pro_monthly', IapProductType.subscription),
      ],
    );

    final service = IapService(
      config: IapConfig(
        subscriptionIds: {'pro_monthly'},
      ),
      verifyPurchase: (_) async => false,
      entitlementResolver: (_) => {'premium'},
      gateway: gateway,
    );

    await service.initialize();
    await service.loadProducts();

    gateway.emitPurchases([
      billingPurchase(
        'pro_monthly',
        IapPurchaseStatus.purchased,
        pendingCompletePurchase: true,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(service.hasEntitlement('premium'), isFalse);
    expect(
      service.currentState.error?.code,
      IapErrorCode.verificationFailed,
    );
    expect(gateway.completedProducts, isEmpty);

    service.dispose();
  });

  test('canceled and failed purchases surface normalized errors', () async {
    final service = IapService(
      config: IapConfig(
        nonConsumableIds: {'lifetime_unlock'},
      ),
      gateway: gateway,
    );

    await service.initialize();

    gateway.emitPurchases([
      billingPurchase(
        'lifetime_unlock',
        IapPurchaseStatus.canceled,
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(
      service.currentState.error?.code,
      IapErrorCode.purchaseCancelled,
    );

    gateway.emitPurchases([
      billingPurchase(
        'lifetime_unlock',
        IapPurchaseStatus.error,
        errorMessage: 'Billing unavailable',
      ),
    ]);

    await Future<void>.delayed(Duration.zero);

    expect(
      service.currentState.error?.code,
      IapErrorCode.purchaseFailed,
    );
    expect(
      service.currentState.error?.message,
      'Billing unavailable',
    );

    service.dispose();
  });

  test('restore delegates to the gateway and resets restoring state', () async {
    final service = IapService(
      config: IapConfig(
        subscriptionIds: {'pro_monthly'},
      ),
      gateway: gateway,
    );

    await service.initialize();
    await service.restore();

    expect(gateway.restoreCalls, 1);
    expect(service.currentState.restoring, isFalse);
    expect(service.currentState.loading, isFalse);

    service.dispose();
  });
}
