import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../deploy/deploy_flow.dart';
import '../deploy/deploy_flow_controller.dart';
import '../domain/agent.dart';
import '../domain/agent_draft.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';

/// Opens the deploy flow for [draft] in a bottom sheet. It is not
/// dismissible by tapping outside or dragging: [DeployFlow] decides when
/// leaving is safe.
Future<void> showDeploySheet(BuildContext context, AgentDraft draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Puls3Colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Puls3Radius.lg),
      ),
    ),
    builder: (_) => DeploySheet(draft: draft),
  );
}

/// Hosts [DeployFlow] for the Studio and publishes the agent to the catalog
/// when it goes live.
class DeploySheet extends StatelessWidget {
  const DeploySheet({super.key, required this.draft});

  final AgentDraft draft;

  void _publish(BuildContext context, DeployResult result) {
    AppScope.of(context).catalog.publish(
      Agent(
        id: '${result.agentId}',
        name: draft.name,
        description: draft.description,
        skills: draft.skills,
        priceUsdcStroops: draft.priceUsdcStroops,
        rating: 5.0,
        stellarAddress: result.agentWallet,
        model: draft.model,
      ),
    );
  }

  void _close(BuildContext context, {String? goTo}) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (goTo != null) router.go(goTo);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final gutter = narrow ? Puls3Spacing.md : Puls3Spacing.lg;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DeployFlow(
            draft: draft,
            gateway: scope.deployGateway,
            wallet: scope.wallet,
            onLive: (result) => _publish(context, result),
            onViewAgent: (result) =>
                _close(context, goTo: '/agent/${result.agentId}'),
            onClose: () => _close(context),
          ),
        ),
      ),
    );
  }
}
