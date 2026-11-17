import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/stellar_explorer.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../studio/studio_gateway.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/agent_hire_panel.dart';

/// Where the testnet USDC faucet lives.
final Uri circleFaucetUrl = Uri.parse('https://faucet.circle.com');

Future<void> _launch(Uri url) async {
  await launchUrl(url, mode: LaunchMode.externalApplication);
}

/// The words for a refused or failed agent-to-agent hire (#312).
String agentHireErrorMessage(AppLocalizations l10n, Object error) =>
    switch (error) {
      StudioAgentHireRefused(:final reason) => switch (reason) {
        AgentHireRefusal.notOwned => l10n.collabErrorNotOwned,
        AgentHireRefusal.selfHire => l10n.collabErrorSelfHire,
        AgentHireRefusal.invalid => l10n.collabErrorInvalid,
        AgentHireRefusal.budgetExceeded => l10n.collabErrorBudget,
        AgentHireRefusal.walletUnavailable => l10n.collabErrorWallet,
        AgentHireRefusal.chainUnavailable => l10n.collabErrorChain,
        AgentHireRefusal.agentUnavailable => l10n.collabErrorAgent,
        AgentHireRefusal.hireNotOwned => l10n.collabErrorHireNotOwned,
      },
      StudioGatewayException(:final message) => message,
      _ => l10n.collabErrorGeneric,
    };

/// Follows the hire [hireId] that the user's live agent [hiringAgentId] made
/// and paid from its own wallet (`StudioEndpoint.getAgentHire`): the
/// container polls it until it is final and maps it to
/// [AgentHireProgressView].
class AgentHireTracker extends StatefulWidget {
  const AgentHireTracker({
    super.key,
    required this.hiringAgentId,
    required this.hireId,
    required this.owner,
    this.pollEvery = const Duration(seconds: 3),
    this.openUrl = _launch,
  });

  final int hiringAgentId;
  final int hireId;

  /// The connected wallet, which owns the hiring agent.
  final String owner;
  final Duration pollEvery;
  final Future<void> Function(Uri url) openUrl;

  @override
  State<AgentHireTracker> createState() => _AgentHireTrackerState();
}

class _AgentHireTrackerState extends State<AgentHireTracker> {
  AgentHireProgress? _progress;
  String? _error;

  /// Every transaction seen so far by escrow purpose: one read only shows
  /// the latest, so earlier ones are kept here.
  final Map<String, String> _transactions = {};
  Timer? _poll;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _schedule(Duration.zero);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _schedule(Duration after) {
    _poll?.cancel();
    _poll = Timer(after, _read);
  }

  Future<void> _read() async {
    if (!mounted) return;
    final gateway = AppScope.of(context).studioGateway;
    try {
      final progress = await gateway.getAgentHire(
        hiringAgentId: widget.hiringAgentId,
        hireId: widget.hireId,
        owner: widget.owner,
      );
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _error = null;
        if (progress.fundTransaction case final fund?) {
          _transactions['fund'] = fund;
        }
        if ((progress.lastPurpose, progress.lastTransaction) case (
          final purpose?,
          final hash?,
        ) when !progress.lastFailed) {
          _transactions[purpose] = hash;
        }
      });
      if (!progress.isFinal) _schedule(widget.pollEvery);
    } on StudioAgentHireRefused catch (e) {
      if (!mounted) return;
      setState(() => _error = agentHireErrorMessage(context.l10n, e));
    } catch (_) {
      // A missed read is retried: the hire goes on on the server.
      if (mounted) _schedule(widget.pollEvery);
    }
  }

  List<AgentHireStepView> _steps(AppLocalizations l10n) {
    final status = _progress?.status;
    final funded = const {'funded', 'submitted', 'completed'}.contains(status);
    final delivered = const {'submitted', 'completed'}.contains(status);
    final completed = status == 'completed';
    final stopped = _progress?.isFinal == true && !completed;
    String? url(String purpose) => switch (_transactions[purpose]) {
      final hash? => stellarExpertTxUrl(hash),
      null => null,
    };
    AgentHireStepState state(bool done, bool previousDone) => done
        ? AgentHireStepState.done
        : previousDone && !stopped
        ? AgentHireStepState.active
        : AgentHireStepState.pending;
    return [
      AgentHireStepView(
        label: l10n.collabStepFunded,
        state: state(funded, true),
        transactionUrl: url('fund'),
      ),
      AgentHireStepView(
        label: l10n.collabStepWorking,
        state: state(delivered, funded),
      ),
      AgentHireStepView(
        label: l10n.collabStepDelivered,
        state: state(delivered, false),
        transactionUrl: url('submit'),
      ),
      AgentHireStepView(
        label: l10n.collabStepCompleted,
        state: state(completed, delivered),
        transactionUrl: url('complete'),
      ),
    ];
  }

  String? _stopped(AppLocalizations l10n) {
    final progress = _progress;
    if (progress == null || !progress.isFinal) return null;
    if (progress.status == 'completed') return null;
    if (progress.status == 'rejected' || progress.status == 'expired') {
      return l10n.collabRefunded;
    }
    return l10n.collabStopped(
      progress.failureReason ?? l10n.collabErrorGeneric,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgentHireProgressView(
          hireId: widget.hireId,
          steps: _steps(l10n),
          result: _progress?.result,
          stopped: _stopped(l10n),
          onOpenTransaction: (url) => unawaited(widget.openUrl(Uri.parse(url))),
        ),
        if (_error case final message?) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            message,
            key: const Key('collab-error'),
            style: Puls3Text.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
