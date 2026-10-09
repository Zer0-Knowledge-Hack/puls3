import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/stellar_explorer.dart';
import '../hire/hire_flow_controller.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/hire_payment_view.dart';

export '../hire/hire_flow_controller.dart' show walletErrorMessage;

/// Opens the hire and pay flow for [agent].
Future<void> showHireSheet(BuildContext context, Agent agent) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the whole app, so the phone's bottom navigation bar does not
    // cover the end of the sheet.
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => HireSheet(agent: agent),
  );
}

Future<void> _launch(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Container for the hire flow (F5): owns the [HireFlowController] and the
/// work request, and maps the flow to [HirePaymentView].
class HireSheet extends StatefulWidget {
  const HireSheet({super.key, required this.agent, this.openUrl = _launch});

  final Agent agent;

  /// Opens the explorer; replaceable in tests.
  final Future<void> Function(Uri url) openUrl;

  @override
  State<HireSheet> createState() => _HireSheetState();
}

class _HireSheetState extends State<HireSheet> {
  final _input = TextEditingController();
  HireFlowController? _flow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _flow ??= HireFlowController(
      agent: widget.agent,
      gateway: scope.hireGateway,
      wallet: scope.wallet,
    );
  }

  @override
  void dispose() {
    _flow?.dispose();
    _input.dispose();
    super.dispose();
  }

  void _run() => unawaited(_flow!.run(_input.text.trim()));

  void _backToMarketplace() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/market');
  }

  @override
  Widget build(BuildContext context) {
    final flow = _flow!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Puls3Spacing.lg,
          0,
          Puls3Spacing.lg,
          Puls3Spacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListenableBuilder(
              listenable: flow,
              builder: (context, _) {
                final hash = flow.payment?.transactionHash;
                return HirePaymentView(
                  phase: _phase(flow),
                  agentName: widget.agent.name,
                  priceUsdcStroops: widget.agent.priceUsdcStroops,
                  destinationAddress: widget.agent.stellarAddress,
                  isDemo: flow.isDemo,
                  inputController: _input,
                  progressLabel: _progress(flow.step),
                  errorMessage: flow.error,
                  hireId: flow.hireId,
                  transactionHash: hash,
                  onConfirm: _run,
                  onRetry: _run,
                  onBackToMarketplace: _backToMarketplace,
                  onOpenExplorer: hash == null || hash.isEmpty
                      ? null
                      : () => unawaited(
                          widget.openUrl(Uri.parse(_explorerUrl(flow))),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static String _explorerUrl(HireFlowController flow) {
    final payment = flow.payment!;
    return payment.explorerUrl ?? stellarExpertTxUrl(payment.transactionHash);
  }

  static HirePhase _phase(HireFlowController flow) {
    if (flow.error != null && !flow.isRunning) return HirePhase.error;
    return switch (flow.step) {
      HireStep.review => HirePhase.review,
      HireStep.done => HirePhase.confirmed,
      _ => HirePhase.signing,
    };
  }

  static String? _progress(HireStep step) => switch (step) {
    HireStep.creating => 'Creating the hire…',
    HireStep.signingCreateJob => 'Sign the escrow job in your wallet (1 of 2).',
    HireStep.submittingCreateJob => 'Creating the escrow job on Stellar…',
    HireStep.preparingFund => 'Waiting for the escrow job to confirm…',
    HireStep.signingFund => 'Sign the payment in your wallet (2 of 2).',
    HireStep.submittingFund => 'Sending the payment to the escrow…',
    HireStep.review || HireStep.done => null,
  };
}
