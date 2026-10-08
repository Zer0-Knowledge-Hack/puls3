import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent_draft.dart';
import '../state/wallet_controller.dart';
import '../ui/organisms/deploy/deploy_flow_view.dart';
import 'deploy_flow_controller.dart';
import 'deploy_gateway.dart';

/// Opens [url] outside the app. Injected so tests never launch a browser.
typedef UrlOpener = Future<void> Function(Uri url);

Future<void> _launchExternally(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

/// Reusable deploy flow for one [draft] (#27): the container that owns the
/// [DeployFlowController] and renders [DeployFlowView].
///
/// It starts after its first frame and knows nothing about the screen that
/// embeds it (the Agent Studio, #37): the host decides what [onLive],
/// [onViewAgent] and [onClose] do. While a step runs, back navigation is
/// blocked so a deploy cannot be abandoned half-way by accident.
class DeployFlow extends StatefulWidget {
  const DeployFlow({
    super.key,
    required this.draft,
    required this.gateway,
    required this.wallet,
    required this.onViewAgent,
    required this.onClose,
    this.onLive,
    this.openUrl = _launchExternally,
    this.stepTimeout = const Duration(seconds: 90),
    this.signatureTimeout = const Duration(minutes: 3),
  });

  final AgentDraft draft;
  final DeployGateway gateway;
  final WalletController wallet;

  /// Called once when the agent goes live, before the result is shown.
  final ValueChanged<DeployResult>? onLive;

  /// Navigates to the live agent.
  final ValueChanged<DeployResult> onViewAgent;

  /// Leaves the flow: after success, or to cancel after an error.
  final VoidCallback onClose;

  final UrlOpener openUrl;

  /// Upper bound for each backend step; null disables it.
  final Duration? stepTimeout;

  /// Upper bound for the wallet prompt; null disables it.
  final Duration? signatureTimeout;

  @override
  State<DeployFlow> createState() => _DeployFlowState();
}

class _DeployFlowState extends State<DeployFlow> {
  late final DeployFlowController _controller = DeployFlowController(
    draft: widget.draft,
    gateway: widget.gateway,
    wallet: widget.wallet,
    stepTimeout: widget.stepTimeout,
    signatureTimeout: widget.signatureTimeout,
  )..addListener(_reportLive);

  bool _reported = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: connecting the wallet notifies other widgets,
    // which must not happen while this one is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.start());
    });
  }

  void _reportLive() {
    final result = _controller.result;
    if (result != null && !_reported) {
      _reported = true;
      widget.onLive?.call(result);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_reportLive)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        // While a wallet prompt (connect or sign) is open the user may still
        // leave: a wallet that never answers must not trap them. Other steps
        // are server-side and bounded by the step timeout.
        final busy = _controller.isRunning && !_controller.isWaitingForWallet;
        final registration = _controller.registration;
        return PopScope(
          canPop: !busy,
          child: DeployFlowView(
            agentName: widget.draft.name,
            step: _controller.step,
            busy: busy,
            isDemo: _controller.isDemo,
            error: _controller.error,
            agentId: registration?.agentId,
            transactionHash: registration?.transactionHash,
            result: _controller.result,
            onRetry: () => unawaited(_controller.retry()),
            onClose: widget.onClose,
            onOpenAgent: () => widget.onViewAgent(_controller.result!),
            onViewTransaction: () {
              final url = _controller.result?.explorerUrl;
              if (url != null) unawaited(widget.openUrl(url));
            },
          ),
        );
      },
    );
  }
}
