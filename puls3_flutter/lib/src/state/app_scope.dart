import 'package:flutter/widgets.dart';

import '../domain/stellar_format.dart';
import 'agent_catalog.dart';
import 'wallet_controller.dart';

/// Exposes app-wide dependencies to containers (screens). Presentational
/// widgets never read from it; they receive data through constructors.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.catalog,
    required this.wallet,
    required this.ids,
    required super.child,
  });

  final AgentCatalog catalog;
  final WalletController wallet;
  final FakeLedgerIds ids;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      catalog != oldWidget.catalog ||
      wallet != oldWidget.wallet ||
      ids != oldWidget.ids;
}
