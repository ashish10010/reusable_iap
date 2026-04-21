import 'package:equatable/equatable.dart';

import 'iap_models.dart';

/// The aggregate state emitted by [IapServiceApi.state].
class IapState extends Equatable {
  const IapState({
    this.available = false,
    this.initialized = false,
    this.loading = false,
    this.restoring = false,
    this.products = const [],
    this.activeEntitlements = const {},
    this.error,
    this.lastPurchase,
  });

  final bool available;
  final bool initialized;
  final bool loading;
  final bool restoring;
  final List<IapProduct> products;
  final Set<String> activeEntitlements;
  final IapError? error;
  final IapPurchase? lastPurchase;

  IapState copyWith({
    bool? available,
    bool? initialized,
    bool? loading,
    bool? restoring,
    List<IapProduct>? products,
    Set<String>? activeEntitlements,
    IapError? error,
    IapPurchase? lastPurchase,
    bool clearError = false,
    bool clearLastPurchase = false,
  }) {
    return IapState(
      available: available ?? this.available,
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      restoring: restoring ?? this.restoring,
      products: products ?? this.products,
      activeEntitlements: activeEntitlements ?? this.activeEntitlements,
      error: clearError ? null : (error ?? this.error),
      lastPurchase:
          clearLastPurchase ? null : (lastPurchase ?? this.lastPurchase),
    );
  }

  @override
  List<Object?> get props => [
        available,
        initialized,
        loading,
        restoring,
        products,
        activeEntitlements,
        error,
        lastPurchase,
      ];
}

typedef IAPState = IapState;
