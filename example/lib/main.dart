import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reusable_iap/reusable_iap.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'reusable_iap Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const IapDemoPage(),
    );
  }
}

class IapDemoPage extends StatefulWidget {
  const IapDemoPage({super.key});

  @override
  State<IapDemoPage> createState() => _IapDemoPageState();
}

class _IapDemoPageState extends State<IapDemoPage> {
  late final IapService _iap;
  late final StreamSubscription<IapState> _subscription;
  IapState _state = const IapState();

  @override
  void initState() {
    super.initState();
    _iap = IapService(
      config: IapConfig(
        products: {
          const IapProductDefinition.subscription('pro_monthly'),
          const IapProductDefinition.subscription('pro_yearly'),
          const IapProductDefinition.nonConsumable('lifetime_unlock'),
          const IapProductDefinition.consumable('coins_100'),
        },
      ),
      verifyPurchase: (purchase) async {
        // Replace this with your backend verification when needed.
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

    _state = _iap.currentState;
    _subscription = _iap.state.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
      });
    });

    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _iap.initialize();
    if (_iap.currentState.available) {
      await _iap.loadProducts();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _iap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entitlements = _state.activeEntitlements.toList(growable: false)
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('reusable_iap Example'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available: ${_state.available}'),
                  Text('Initialized: ${_state.initialized}'),
                  Text('Loading: ${_state.loading}'),
                  Text('Restoring: ${_state.restoring}'),
                  const SizedBox(height: 12),
                  Text(
                    'Entitlements: ${entitlements.isEmpty ? 'none' : entitlements.join(', ')}',
                  ),
                  if (_state.lastPurchase != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Last purchase: ${_state.lastPurchase!.productId} (${_state.lastPurchase!.status.name})',
                    ),
                  ],
                  if (_state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _state.error!.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: _state.loading ? null : _initialize,
                child: const Text('Reload Catalog'),
              ),
              OutlinedButton(
                onPressed:
                    !_state.available || _state.loading ? null : _iap.restore,
                child: const Text('Restore Purchases'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Products',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_state.products.isEmpty)
            const Text(
              'No products loaded yet. Replace the sample IDs with products from your store setup.',
            ),
          for (final product in _state.products)
            Card(
              child: ListTile(
                title: Text(product.title),
                subtitle: Text(
                  '${product.description}\n${product.price} - ${product.type.name}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed:
                      !_state.available || _state.loading
                          ? null
                          : () => _iap.buy(product.id),
                  child: const Text('Buy'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
