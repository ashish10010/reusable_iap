import 'package:equatable/equatable.dart';

/// Resolves app-facing entitlements from a normalized purchase.
typedef EntitlementResolver = Set<String> Function(IapPurchase purchase);

/// Verifies a normalized purchase before entitlements are granted.
typedef PurchaseVerifier = Future<bool> Function(IapPurchase purchase);

/// The supported store product types.
enum IapProductType {
  consumable,
  nonConsumable,
  subscription,
}

extension IapProductTypeX on IapProductType {
  bool get isSubscription => this == IapProductType.subscription;
}

/// A catalog entry describing how a store product should be treated.
class IapProductDefinition extends Equatable {
  const IapProductDefinition({
    required this.id,
    required this.type,
  });

  const IapProductDefinition.consumable(String id)
      : this(id: id, type: IapProductType.consumable);

  const IapProductDefinition.nonConsumable(String id)
      : this(id: id, type: IapProductType.nonConsumable);

  const IapProductDefinition.subscription(String id)
      : this(id: id, type: IapProductType.subscription);

  final String id;
  final IapProductType type;

  @override
  List<Object?> get props => [id, type];
}

/// Stable, package-owned product details exposed to consuming apps.
class IapProduct extends Equatable {
  const IapProduct({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.price,
    this.currencyCode,
    this.rawPrice,
  });

  final String id;
  final IapProductType type;
  final String title;
  final String description;
  final String price;
  final String? currencyCode;
  final double? rawPrice;

  bool get isSubscription => type.isSubscription;

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        description,
        price,
        currencyCode,
        rawPrice,
      ];
}

/// A normalized purchase lifecycle status.
enum IapPurchaseStatus {
  pending,
  purchased,
  restored,
  canceled,
  error,
}

/// Normalized verification payload extracted from the platform purchase.
class IapVerificationData extends Equatable {
  const IapVerificationData({
    required this.localVerificationData,
    required this.serverVerificationData,
    required this.source,
  });

  final String localVerificationData;
  final String serverVerificationData;
  final String source;

  @override
  List<Object?> get props => [
        localVerificationData,
        serverVerificationData,
        source,
      ];
}

/// Stable, package-owned purchase details exposed to consuming apps.
class IapPurchase extends Equatable {
  const IapPurchase({
    required this.productId,
    required this.status,
    this.productType,
    this.purchaseId,
    this.transactionDate,
    this.verificationData,
    this.errorMessage,
    this.pendingCompletePurchase = false,
  });

  final String productId;
  final IapPurchaseStatus status;
  final IapProductType? productType;
  final String? purchaseId;
  final String? transactionDate;
  final IapVerificationData? verificationData;
  final String? errorMessage;
  final bool pendingCompletePurchase;

  bool get isRestored => status == IapPurchaseStatus.restored;

  IapPurchase copyWith({
    String? productId,
    IapPurchaseStatus? status,
    IapProductType? productType,
    String? purchaseId,
    String? transactionDate,
    IapVerificationData? verificationData,
    String? errorMessage,
    bool? pendingCompletePurchase,
  }) {
    return IapPurchase(
      productId: productId ?? this.productId,
      status: status ?? this.status,
      productType: productType ?? this.productType,
      purchaseId: purchaseId ?? this.purchaseId,
      transactionDate: transactionDate ?? this.transactionDate,
      verificationData: verificationData ?? this.verificationData,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingCompletePurchase:
          pendingCompletePurchase ?? this.pendingCompletePurchase,
    );
  }

  @override
  List<Object?> get props => [
        productId,
        status,
        productType,
        purchaseId,
        transactionDate,
        verificationData,
        errorMessage,
        pendingCompletePurchase,
      ];
}

/// Stable error codes apps can branch on without parsing strings.
enum IapErrorCode {
  storeUnavailable,
  emptyCatalog,
  productQueryFailed,
  productsNotFound,
  unknownProduct,
  purchaseFailed,
  purchaseCancelled,
  verificationFailed,
  purchaseStreamFailed,
  purchaseCompletionFailed,
  restoreFailed,
}

/// A normalized IAP error exposed through [IapState].
class IapError extends Equatable {
  const IapError({
    required this.code,
    required this.message,
  });

  final IapErrorCode code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}
