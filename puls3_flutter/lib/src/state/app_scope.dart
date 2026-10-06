import 'package:flutter/widgets.dart';

import '../deploy/deploy_gateway.dart';
import '../domain/stellar_format.dart';
import 'agent_catalog.dart';
import 'notification_center.dart';
import 'profile_controller.dart';
import 'wallet_controller.dart';

/// Exposes app-wide dependencies to containers (screens). Presentational
/// widgets never read from it; they receive data through constructors.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.catalog,
    required this.wallet,
    required this.ids,
    required this.deployGateway,
    required this.notifications,
    required this.profile,
    required super.child,
  });

  final AgentCatalog catalog;
  final WalletController wallet;
  final FakeLedgerIds ids;
  final DeployGateway deployGateway;
  final NotificationCenter notifications;
  final ProfileController profile;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in the widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      catalog != oldWidget.catalog ||
      wallet != oldWidget.wallet ||
      ids != oldWidget.ids ||
      deployGateway != oldWidget.deployGateway ||
      notifications != oldWidget.notifications ||
      profile != oldWidget.profile;
}
