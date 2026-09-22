import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/deploy_progress_view.dart';
import '../domain/agent_draft.dart';

/// Opens the staged mock deploy flow for [draft].
Future<void> showDeploySheet(BuildContext context, AgentDraft draft) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => DeploySheet(draft: draft),
  );
}

/// Container that fakes the deploy pipeline (about 2.5 s in total) and
/// publishes the agent to the in-memory catalog when it goes live.
class DeploySheet extends StatefulWidget {
  const DeploySheet({super.key, required this.draft});

  final AgentDraft draft;

  static const steps = [
    'Creating wallet…',
    'Registering identity on Soroban…',
    'Live',
  ];

  static const _stepDurations = [
    Duration(milliseconds: 900),
    Duration(milliseconds: 1000),
    Duration(milliseconds: 600),
  ];

  @override
  State<DeploySheet> createState() => _DeploySheetState();
}

class _DeploySheetState extends State<DeploySheet> {
  int _completed = 0;
  String? _contractId;
  String? _txHash;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    final scope = AppScope.of(context);
    final ids = scope.ids;
    final catalog = scope.catalog;

    final agentWallet = ids.accountAddress();
    for (final duration in DeploySheet._stepDurations) {
      await Future<void>.delayed(duration);
      if (!mounted) return;
      setState(() => _completed++);
    }

    final contractId = ids.contractId();
    final draft = widget.draft;
    catalog.publish(
      Agent(
        id: contractId.toLowerCase().substring(0, 12),
        name: draft.name,
        description: draft.description,
        skills: draft.skills,
        priceUsdcStroops: draft.priceUsdcStroops,
        rating: 5.0,
        stellarAddress: agentWallet,
        model: draft.model,
      ),
    );
    setState(() {
      _contractId = contractId;
      _txHash = ids.txHash();
    });
  }

  void _close(String? goTo) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    if (goTo != null) router.go(goTo);
  }

  @override
  Widget build(BuildContext context) {
    final live = _completed >= DeploySheet.steps.length && _txHash != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Puls3Spacing.lg,
          0,
          Puls3Spacing.lg,
          Puls3Spacing.lg,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DeployProgressView(
            agentName: widget.draft.name,
            steps: DeploySheet.steps,
            // Hold the last step active until ids are ready.
            completedSteps: live ? _completed : _completed.clamp(0, 2),
            contractId: _contractId,
            txHash: _txHash,
            onViewInMarketplace: () => _close('/market'),
            onBackToStudio: () => _close(null),
          ),
        ),
      ),
    );
  }
}
