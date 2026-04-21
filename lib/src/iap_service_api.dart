import 'iap_models.dart';
import 'iap_state.dart';

/// Public headless API for the reusable IAP service.
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
