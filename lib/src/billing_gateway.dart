import 'package:equatable/equatable.dart';
import 'package:resuable_iap/src/iap_models.dart';

/// Test seam around the underlying billing implementation.
abstract interface class BillingGateway {
  Stream<List<BillingPurchase>> get purchaseStream;

  Future<bool> isAvailable();

  Future<BillingQueryResult> queryProducts(Set<IapProductDefinition> products);

  Future<void> buyConsumable(
    String productId, {
    bool autoConsume = true,
  });

  Future<void> buyNonConsumable(String productId);

  Future<void> restorePurchases();

  Future<void> completePurchase(BillingPurchase purchase);
}

/// Normalized product query results returned by a [BillingGateway].
class BillingQueryResult extends Equatable {
  const BillingQueryResult({
    this.products = const [],
    this.notFoundIds = const {},
    this.errorMessage,
  });

  final List<BillingProduct> products;
  final Set<String> notFoundIds;
  final String? errorMessage;

  @override
  List<Object?> get props => [products, notFoundIds, errorMessage];
}

/// A gateway product that keeps normalized data and raw platform details.
class BillingProduct extends Equatable {
  const BillingProduct({
    required this.product,
    this.rawProduct,
  });

  final IapProduct product;
  final Object? rawProduct;

  @override
  List<Object?> get props => [product];
}

/// A gateway purchase that keeps normalized data and raw platform details.
class BillingPurchase extends Equatable {
  const BillingPurchase({
    required this.purchase,
    this.rawPurchase,
  });

  final IapPurchase purchase;
  final Object? rawPurchase;

  BillingPurchase copyWith({
    IapPurchase? purchase,
    Object? rawPurchase,
  }) {
    return BillingPurchase(
      purchase: purchase ?? this.purchase,
      rawPurchase: rawPurchase ?? this.rawPurchase,
    );
  }

  @override
  List<Object?> get props => [purchase];
}
