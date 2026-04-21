# resuable_iap

`resuable_iap` is a headless Flutter in-app purchase package built on top of [`in_app_purchase`](https://pub.dev/packages/in_app_purchase).

It focuses on the service layer, not UI. You bring your own paywall, buttons, branding, and state-management approach.

## What It Solves

- Headless `IapServiceApi` for store initialization, catalog loading, buying, restoring, and entitlement checks
- Support for consumables, non-consumables, and subscriptions
- Normalized `IapProduct`, `IapPurchase`, `IapError`, and `IapState` models
- Centralized purchase stream handling
- Internal purchase completion / acknowledgement handling
- Entitlement mapping through an app-provided resolver
- Pluggable purchase verification hook
- Testable architecture through the `BillingGateway` abstraction

## What It Does Not Do

- Render a paywall
- Impose a design system
- Depend on Provider, Bloc, Riverpod, or any other state-management package
- Hardcode your entitlement model
- Pretend local-only verification is correct for every app

## Install

Add the package and configure your store products in App Store Connect / Play Console as usual.

```yaml
dependencies:
  resuable_iap: ^0.1.0
```

## Quick Start

```dart
import 'package:resuable_iap/resuable_iap.dart';

final iap = IapService(
  config: IapConfig(
    products: {
      const IapProductDefinition.subscription('pro_monthly'),
      const IapProductDefinition.subscription('pro_yearly'),
      const IapProductDefinition.nonConsumable('lifetime_unlock'),
      const IapProductDefinition.consumable('coins_100'),
    },
  ),
  verifyPurchase: (purchase) async {
    // Call your backend here when you need server-side trust.
    return true;
  },
  entitlementResolver: (purchase) {
    switch (purchase.productId) {
      case 'pro_monthly':
      case 'pro_yearly':
      case 'lifetime_unlock':
        return {'premium'};
      default:
        return const <String>{};
    }
  },
);

await iap.initialize();
final products = await iap.loadProducts();

iap.state.listen((state) {
  if (state.error != null) {
    debugPrint(state.error!.message);
  }

  if (state.lastPurchase?.status == IapPurchaseStatus.purchased &&
      iap.hasEntitlement('premium')) {
    debugPrint('Premium unlocked');
  }
});

await iap.buy(products.first.id);
await iap.restore();
```

## Public API

```dart
abstract interface class IapServiceApi {
  Stream<IapState> get state;
  IapState get currentState;
  Future<void> initialize();
  Future<List<IapProduct>> loadProducts();
  Future<void> buy(String productId);
  Future<void> restore();
  bool hasEntitlement(String entitlement);
  void dispose();
}
```

## Product Catalog

`IapConfig` supports both the new explicit product-definition API and the older grouped-ID style:

```dart
final config = IapConfig(
  consumableIds: {'coins_100'},
  nonConsumableIds: {'lifetime_unlock'},
  subscriptionIds: {'pro_monthly', 'pro_yearly'},
);
```

Every loaded product is exposed as an `IapProduct`, so your app does not have to depend directly on plugin product models:

- `id`
- `title`
- `description`
- `price`
- `type`
- `isSubscription`
- `currencyCode`
- `rawPrice`

## Entitlements

Product IDs are store-facing. Entitlements are app-facing.

For example, `pro_monthly`, `pro_yearly`, and `lifetime_unlock` can all map to the same entitlement like `premium`.

## Verification

`verifyPurchase` is intentionally app-owned. Some apps can accept local checks, while others should call a backend before granting access.

If verification returns `false`, the service does not grant entitlements and does not acknowledge the purchase.

## Testing

The service depends on `BillingGateway`, not directly on `InAppPurchase.instance`, so you can unit test store availability, query results, purchase success, cancellation, restore flows, and verification failures without talking to the real stores.

## Important Publishing Notes

- Fill in a real `LICENSE` before publishing.
- Add repository / issue tracker metadata in `pubspec.yaml` for a better pub.dev score.
- Store configuration, backend receipt validation, and platform-specific setup are still required in the consuming app.
