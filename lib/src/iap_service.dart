import 'dart:async';

import 'package:resuable_iap/src/billing_gateway.dart';
import 'package:resuable_iap/src/flutter_billing_gateway.dart';
import 'package:resuable_iap/src/iap_config.dart';
import 'package:resuable_iap/src/iap_models.dart';
import 'package:resuable_iap/src/iap_service_api.dart';
import 'package:resuable_iap/src/iap_state.dart';

Set<String> _emptyEntitlements(IapPurchase purchase) => const <String>{};

Future<bool> _acceptAllPurchases(IapPurchase purchase) async => true;

/// A headless IAP service built on top of [BillingGateway].
class IapService implements IapServiceApi {
  IapService({
    required this.config,
    PurchaseVerifier? verifyPurchase,
    EntitlementResolver? entitlementResolver,
    BillingGateway? gateway,
  })  : _verifyPurchase = verifyPurchase ?? _acceptAllPurchases,
        _entitlementResolver = entitlementResolver ?? _emptyEntitlements,
        _gateway = gateway ?? FlutterBillingGateway();

  final IapConfig config;
  final PurchaseVerifier _verifyPurchase;
  final EntitlementResolver _entitlementResolver;
  final BillingGateway _gateway;

  final StreamController<IapState> _stateController =
      StreamController<IapState>.broadcast();

  final Map<String, BillingProduct> _catalogById = <String, BillingProduct>{};

  StreamSubscription<List<BillingPurchase>>? _purchaseSubscription;
  IapState _state = const IapState();
  bool _disposed = false;

  @override
  Stream<IapState> get state async* {
    yield _state;
    yield* _stateController.stream;
  }

  @override
  IapState get currentState => _state;

  void _emit(IapState newState) {
    if (_disposed) {
      return;
    }
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> initialize() async {
    _purchaseSubscription ??= _gateway.purchaseStream.listen(
      (purchases) {
        unawaited(
          _handlePurchaseUpdates(purchases).catchError(
            (Object error, StackTrace stackTrace) {
              _emit(
                _state.copyWith(
                  loading: false,
                  restoring: false,
                  error: IapError(
                    code: IapErrorCode.purchaseStreamFailed,
                    message: 'Purchase stream error: $error',
                  ),
                ),
              );
            },
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        _emit(
          _state.copyWith(
            loading: false,
            restoring: false,
            error: IapError(
              code: IapErrorCode.purchaseStreamFailed,
              message: 'Purchase stream error: $error',
            ),
          ),
        );
      },
    );

    _emit(
      _state.copyWith(
        loading: true,
        clearError: true,
      ),
    );

    final available = await _gateway.isAvailable();
    if (!available) {
      _emit(
        _state.copyWith(
          available: false,
          initialized: true,
          loading: false,
          error: const IapError(
            code: IapErrorCode.storeUnavailable,
            message: 'In-app purchases are not available on this device.',
          ),
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        available: true,
        initialized: true,
        loading: false,
        clearError: true,
      ),
    );
  }

  @override
  Future<List<IapProduct>> loadProducts() async {
    await _ensureInitialized();
    if (!_state.available) {
      return _state.products;
    }

    if (config.productIds.isEmpty) {
      _emit(
        _state.copyWith(
          loading: false,
          error: const IapError(
            code: IapErrorCode.emptyCatalog,
            message: 'No product IDs were configured.',
          ),
        ),
      );
      return const <IapProduct>[];
    }

    _emit(
      _state.copyWith(
        loading: true,
        clearError: true,
      ),
    );

    final response = await _gateway.queryProducts(config.products);
    _catalogById
      ..clear()
      ..addEntries(
        response.products.map(
          (product) => MapEntry(product.product.id, product),
        ),
      );

    final products = response.products
        .map((product) => product.product)
        .toList(growable: false)
      ..sort((left, right) => left.id.compareTo(right.id));

    final error = _catalogErrorFor(response);
    _emit(
      _state.copyWith(
        loading: false,
        products: products,
        error: error,
        clearError: error == null,
      ),
    );

    return products;
  }

  @override
  Future<void> buy(String productId) async {
    await _ensureInitialized();
    if (!_state.available) {
      return;
    }

    final product = await _loadCatalogProduct(productId);
    if (product == null) {
      _emit(
        _state.copyWith(
          loading: false,
          error: IapError(
            code: IapErrorCode.unknownProduct,
            message: 'Unknown product ID: $productId',
          ),
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        loading: true,
        clearError: true,
        clearLastPurchase: true,
      ),
    );

    try {
      switch (product.product.type) {
        case IapProductType.consumable:
          await _gateway.buyConsumable(
            productId,
            autoConsume: config.autoConsumeConsumables,
          );
          break;
        case IapProductType.nonConsumable:
        case IapProductType.subscription:
          // The underlying Flutter plugin uses the same API for
          // non-consumables and subscriptions.
          await _gateway.buyNonConsumable(productId);
          break;
      }
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          error: IapError(
            code: IapErrorCode.purchaseFailed,
            message: 'Unable to start the purchase flow for $productId: $error',
          ),
        ),
      );
    }
  }

  @override
  Future<void> restore() async {
    await _ensureInitialized();
    if (!_state.available) {
      return;
    }

    _emit(
      _state.copyWith(
        loading: true,
        restoring: true,
        clearError: true,
        clearLastPurchase: true,
      ),
    );

    try {
      await _gateway.restorePurchases();
      if (_state.restoring) {
        _emit(
          _state.copyWith(
            loading: false,
            restoring: false,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          restoring: false,
          error: IapError(
            code: IapErrorCode.restoreFailed,
            message: 'Unable to restore purchases: $error',
          ),
        ),
      );
    }
  }

  @override
  bool hasEntitlement(String entitlement) {
    return _state.activeEntitlements.contains(entitlement);
  }

  Future<void> _ensureInitialized() async {
    if (!_state.initialized) {
      await initialize();
    }
  }

  Future<BillingProduct?> _loadCatalogProduct(String productId) async {
    final cached = _catalogById[productId];
    if (cached != null) {
      return cached;
    }

    await loadProducts();
    return _catalogById[productId];
  }

  IapError? _catalogErrorFor(BillingQueryResult response) {
    if (response.errorMessage != null && response.errorMessage!.isNotEmpty) {
      return IapError(
        code: IapErrorCode.productQueryFailed,
        message: response.errorMessage!,
      );
    }

    if (response.notFoundIds.isNotEmpty) {
      final missingIds = response.notFoundIds.toList(growable: false)..sort();
      return IapError(
        code: IapErrorCode.productsNotFound,
        message: 'Products not found: ${missingIds.join(', ')}',
      );
    }

    return null;
  }

  Future<void> _handlePurchaseUpdates(
    List<BillingPurchase> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      final normalizedPurchase = _normalizePurchase(purchase.purchase);
      final normalizedBillingPurchase =
          purchase.copyWith(purchase: normalizedPurchase);

      switch (normalizedPurchase.status) {
        case IapPurchaseStatus.pending:
          _emit(
            _state.copyWith(
              loading: true,
              restoring: normalizedPurchase.isRestored && _state.restoring,
              lastPurchase: normalizedPurchase,
              clearError: true,
            ),
          );
          break;
        case IapPurchaseStatus.error:
          _emit(
            _state.copyWith(
              loading: false,
              restoring: false,
              lastPurchase: normalizedPurchase,
              error: IapError(
                code: IapErrorCode.purchaseFailed,
                message:
                    normalizedPurchase.errorMessage ?? 'Purchase failed.',
              ),
            ),
          );
          break;
        case IapPurchaseStatus.canceled:
          _emit(
            _state.copyWith(
              loading: false,
              restoring: false,
              lastPurchase: normalizedPurchase,
              error: IapError(
                code: IapErrorCode.purchaseCancelled,
                message:
                    normalizedPurchase.errorMessage ?? 'Purchase was cancelled.',
              ),
            ),
          );
          break;
        case IapPurchaseStatus.purchased:
        case IapPurchaseStatus.restored:
          await _processSuccessfulPurchase(normalizedBillingPurchase);
          break;
      }
    }
  }

  IapPurchase _normalizePurchase(IapPurchase purchase) {
    final productType =
        purchase.productType ?? config.productTypeFor(purchase.productId);
    return purchase.copyWith(productType: productType);
  }

  Future<void> _processSuccessfulPurchase(BillingPurchase purchase) async {
    final normalizedPurchase = purchase.purchase;

    try {
      final isValid = await _verifyPurchase(normalizedPurchase);
      if (!isValid) {
        _emit(
          _state.copyWith(
            loading: false,
            restoring: false,
            lastPurchase: normalizedPurchase,
            error: IapError(
              code: IapErrorCode.verificationFailed,
              message:
                  'Purchase verification failed for ${normalizedPurchase.productId}.',
            ),
          ),
        );
        return;
      }

      final entitlements = {
        ..._state.activeEntitlements,
        ..._entitlementResolver(normalizedPurchase),
      };

      _emit(
        _state.copyWith(
          loading: false,
          restoring: false,
          activeEntitlements: entitlements,
          lastPurchase: normalizedPurchase,
          clearError: true,
        ),
      );

      await _completePurchaseIfNeeded(purchase);
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          restoring: false,
          lastPurchase: normalizedPurchase,
          error: IapError(
            code: IapErrorCode.verificationFailed,
            message: 'Purchase verification error: $error',
          ),
        ),
      );
    }
  }

  Future<void> _completePurchaseIfNeeded(BillingPurchase purchase) async {
    if (!purchase.purchase.pendingCompletePurchase) {
      return;
    }

    try {
      await _gateway.completePurchase(purchase);
    } catch (error) {
      _emit(
        _state.copyWith(
          error: IapError(
            code: IapErrorCode.purchaseCompletionFailed,
            message:
                'Purchase completed but acknowledgement failed: $error',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_purchaseSubscription?.cancel());
    _purchaseSubscription = null;
    _catalogById.clear();
    _stateController.close();
  }
}
