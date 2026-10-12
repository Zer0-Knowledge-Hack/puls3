import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../deploy/deploy_flow.dart';
import '../deploy/deploy_flow_controller.dart';
import '../domain/agent.dart';
import '../domain/agent_draft.dart';
import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';

/// Opens the deploy flow for [draft] in a bottom sheet. It is not
/// dismissible by tapping outside or dragging: [DeployFlow] decides when
/// leaving is safe. [onLive] also runs when the agent goes live, for the
/// Studio to record the deploy on its draft.
Future<void> showDeploySheet(
  BuildContext context,
  AgentDraft draft, {
  ValueChanged<DeployResult>? onLive,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the whole app, so the phone's bottom navigation bar does not
    // cover the end of the sheet.
    useRootNavigator: true,
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
    builder: (_) => DeploySheet(draft: draft, onLive: onLive),
  );
}

/// Hosts [DeployFlow] for the Studio and publishes the agent to the catalog
/// when it goes live.
class DeploySheet extends StatelessWidget {
  const DeploySheet({super.key, required this.draft, this.onLive});

  final AgentDraft draft;
  final ValueChanged<DeployResult>? onLive;

  void _publish(BuildContext context, DeployResult result) {
    onLive?.call(result);
    // A demo deploy created nothing: never list it as a real agent.
    if (result.isDemo) return;
    AppScope.of(context).catalog.publish(
      Agent(
        id: '${result.agentId}',
        name: draft.name,
        description: draft.description,
        skills: draft.skills,
        priceUsdcStroops: draft.priceUsdcStroops,
        // No reviews yet: RatingBadge hides a 0.0 rating.
        rating: 0.0,
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
    final narrow =
        MediaQuery.sizeOf(context).width < Puls3Breakpoints.narrowGutter;
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
