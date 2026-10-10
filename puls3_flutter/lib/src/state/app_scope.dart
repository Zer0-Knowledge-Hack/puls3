import 'package:flutter/widgets.dart';

import '../deploy/deploy_gateway.dart';
import '../hire/hire_flow_store.dart';
import '../hire/hire_gateway.dart';
import 'agent_catalog.dart';
import 'wallet_controller.dart';

/// Exposes app-wide dependencies to containers (screens). Presentational
/// widgets never read from it; they receive data through constructors.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.catalog,
    required this.wallet,
    required this.deployGateway,
    required this.hireGateway,
    required this.hireFlowStore,
    required super.child,
  });

  final AgentCatalog catalog;
  final WalletController wallet;
  final DeployGateway deployGateway;
  final HireGateway hireGateway;

  /// Unfinished hires, so a closed sheet or a reload resumes them.
  final HireFlowStore hireFlowStore;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      catalog != oldWidget.catalog ||
      wallet != oldWidget.wallet ||
      deployGateway != oldWidget.deployGateway ||
      hireGateway != oldWidget.hireGateway ||
      hireFlowStore != oldWidget.hireFlowStore;
}
