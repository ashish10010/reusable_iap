# reusable_iap

`reusable_iap` is a headless Flutter in-app purchase service built on top of [`in_app_purchase`](https://pub.dev/packages/in_app_purchase).

It wraps store availability checks, product loading, purchase updates, restore flows, entitlement mapping, verification, and purchase completion without forcing a paywall UI or a state-management package.

## Features

- Headless `IapServiceApi` for `initialize`, `loadProducts`, `buy`, `restore`, and entitlement checks
- Support for consumables, non-consumables, and subscriptions
- Normalized `IapProduct`, `IapPurchase`, `IapState`, and `IapError` models
- Centralized purchase lifecycle handling for pending, purchased, restored, canceled, and error states
- Internal transaction completion / acknowledgement handling
- App-defined entitlement mapping through `EntitlementResolver`
- App-defined verification through `PurchaseVerifier`
- Testable design through the `BillingGateway` abstraction

## What This Package Does Not Do

- Render a paywall
- Impose app branding or button styles
- Depend on Provider, Bloc, Riverpod, or any other state-management library
- Assume product IDs are the same thing as entitlements
- Force one backend verification strategy

## Installation

```yaml
dependencies:
  reusable_iap: ^0.1.0
```

After adding the package, configure your products in App Store Connect / Google Play Console as usual.

## Quick Start

```dart
import 'package:reusable_iap/reusable_iap.dart';

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
    // Call your backend when you need server-side validation.
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

final subscription = iap.state.listen((state) {
  if (state.error != null) {
    // Show a friendly error message.
  }

  if (iap.hasEntitlement('premium')) {
    // Unlock premium features.
  }
});

await iap.buy(products.first.id);
await iap.restore();

await subscription.cancel();
iap.dispose();
```

## Product IDs vs Entitlements

Product IDs are store-facing. Entitlements are app-facing.

That means products like `pro_monthly`, `pro_yearly`, and `lifetime_unlock` can all unlock the same entitlement such as `premium`.

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

## Testing

The service depends on `BillingGateway`, not directly on `InAppPurchase.instance`, so you can unit test:

- store available / unavailable
- product catalog queries
- successful purchases
- canceled or failed purchases
- restore flows
- verification failures

## Example

A minimal example app is included in `example/lib/main.dart`. Replace the sample product IDs with your own and run it on a configured iOS or Android device.

## Publishing Notes

- Add a real open-source license to `LICENSE` before publishing.
- Add repository, issue tracker, and documentation URLs to `pubspec.yaml` when you have them.
- Verify your store products, test accounts, and backend receipt validation in the consuming app.
- Use the checklist in `PUBLISH_CHECKLIST.md` before running `flutter pub publish`.
