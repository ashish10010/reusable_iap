import 'iap_models.dart';

/// Catalog configuration for the reusable IAP service.
class IapConfig {
  IapConfig({
    Set<IapProductDefinition> products = const {},
    Set<String> consumableIds = const {},
    Set<String> consumeableIds = const {},
    Set<String> nonConsumableIds = const {},
    Set<String> nonConsumeableIds = const {},
    Set<String> subscriptionIds = const {},
    this.autoConsumeConsumables = true,
  }) : products = Set.unmodifiable({
          ...products,
          ...consumableIds.map(IapProductDefinition.consumable),
          ...consumeableIds.map(IapProductDefinition.consumable),
          ...nonConsumableIds.map(IapProductDefinition.nonConsumable),
          ...nonConsumeableIds.map(IapProductDefinition.nonConsumable),
          ...subscriptionIds.map(IapProductDefinition.subscription),
        }) {
    final uniqueProductIds = this.products.map((product) => product.id).toSet();
    if (uniqueProductIds.length != this.products.length) {
      throw ArgumentError(
        'Each product ID must appear only once in the catalog.',
      );
    }
  }

  final Set<IapProductDefinition> products;

  /// Mirrors the native plugin's consumable auto-consume flag.
  final bool autoConsumeConsumables;

  Set<String> get productIds => {
        for (final product in products) product.id,
      };

  Set<String> get consumableIds => {
        for (final product in products)
          if (product.type == IapProductType.consumable) product.id,
      };

  Set<String> get consumeableIds => consumableIds;

  Set<String> get nonConsumableIds => {
        for (final product in products)
          if (product.type == IapProductType.nonConsumable) product.id,
      };

  Set<String> get nonConsumeableIds => nonConsumableIds;

  Set<String> get subscriptionIds => {
        for (final product in products)
          if (product.type == IapProductType.subscription) product.id,
      };

  Set<String> get allproducts => productIds;

  IapProductType? productTypeFor(String productId) {
    for (final product in products) {
      if (product.id == productId) {
        return product.type;
      }
    }
    return null;
  }
}
