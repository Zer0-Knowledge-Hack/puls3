import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/stellar_explorer.dart';
import '../domain/usdc.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../studio/studio_gateway.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/copy_to_clipboard.dart';
import '../ui/organisms/agent_hire_panel.dart';

/// Where the testnet USDC faucet lives.
final Uri circleFaucetUrl = Uri.parse('https://faucet.circle.com');

/// "Collaborate: hire another agent" (#312, SOW week 2): the builder's live
/// agent [hiringAgentId] hires a catalog agent and pays it from its own
/// wallet. The container: it loads the catalog, calls the [StudioGateway]
/// and polls the hire until it is final.
class AgentCollaborationSection extends StatefulWidget {
  const AgentCollaborationSection({
    super.key,
    required this.hiringAgentId,
    required this.owner,
    this.pollEvery = const Duration(seconds: 3),
  });

  /// The registry id of the builder's live agent.
  final int hiringAgentId;

  /// The connected wallet, which owns the agent.
  final String owner;
  final Duration pollEvery;

  @override
  State<AgentCollaborationSection> createState() =>
      _AgentCollaborationSectionState();
}

class _AgentCollaborationSectionState extends State<AgentCollaborationSection> {
  final _instructions = TextEditingController();
  final _budget = TextEditingController();
  Agent? _selected;
  bool _hiring = false;
  String? _error;
  String? _hiringWallet;

  int? _hireId;
  AgentHireProgress? _progress;

  /// Every transaction seen so far by escrow purpose: one read only shows
  /// the latest, so earlier ones are kept here.
  final Map<String, String> _transactions = {};
  Timer? _poll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context).catalog.load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _instructions.dispose();
    _budget.dispose();
    super.dispose();
  }

  bool _isSelf(Agent agent) =>
      agent.registryId == widget.hiringAgentId ||
      agent.id == '${widget.hiringAgentId}';

  void _select(Agent? agent) => setState(() {
    _selected = agent;
    _error = null;
    if (agent != null) _budget.text = formatUsdc(agent.priceUsdcStroops);
  });

  Future<void> _hire() async {
    final agent = _selected;
    final l10n = context.l10n;
    if (agent == null) return;
    final input = _instructions.text.trim();
    final budget = parseUsdcToStroops(_budget.text);
    if (input.isEmpty) {
      setState(() => _error = l10n.collabErrorInvalid);
      return;
    }
    if (budget == null || budget <= 0) {
      setState(() => _error = l10n.collabBudgetInvalid);
      return;
    }
    setState(() {
      _hiring = true;
      _error = null;
    });
    final gateway = AppScope.of(context).studioGateway;
    try {
      final started = await gateway.hireAgentAs(
        hiringAgentId: widget.hiringAgentId,
        agentId: agent.registryId ?? int.parse(agent.id),
        input: input,
        budgetUsdcStroops: budget,
        owner: widget.owner,
      );
      if (!mounted) return;
      setState(() {
        _hiring = false;
        _hiringWallet = started.hiringWallet;
        _hireId = started.hireId;
        _progress = null;
        _transactions.clear();
      });
      _schedule(Duration.zero);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiring = false;
        _error = _message(l10n, e);
      });
    }
  }

  void _schedule(Duration after) {
    _poll?.cancel();
    _poll = Timer(after, _read);
  }

  Future<void> _read() async {
    final hireId = _hireId;
    if (hireId == null || !mounted) return;
    final gateway = AppScope.of(context).studioGateway;
    try {
      final progress = await gateway.getAgentHire(
        hiringAgentId: widget.hiringAgentId,
        hireId: hireId,
        owner: widget.owner,
      );
      if (!mounted || hireId != _hireId) return;
      setState(() {
        _progress = progress;
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
      setState(() => _error = _message(context.l10n, e));
    } catch (_) {
      // A missed read is retried: the hire goes on on the server.
      if (mounted) _schedule(widget.pollEvery);
    }
  }

  void _reset() => setState(() {
    _poll?.cancel();
    _hireId = null;
    _progress = null;
    _transactions.clear();
  });

  Future<void> _open(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  static String _message(AppLocalizations l10n, Object error) =>
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
    final catalog = AppScope.of(context).catalog;
    return ListenableBuilder(
      listenable: catalog,
      builder: (context, _) {
        final agents = catalog.agents;
        Agent? self;
        for (final agent in agents) {
          if (_isSelf(agent)) self = agent;
        }
        final candidates = [
          for (final agent in agents)
            if (agent.hireable &&
                !_isSelf(agent) &&
                (agent.registryId != null || int.tryParse(agent.id) != null))
              agent,
        ];
        final selected = candidates.contains(_selected) ? _selected : null;
        final wallet = _hiringWallet ?? self?.stellarAddress;
        final hireId = _hireId;
        final progress = _progress;
        return Column(
          key: const Key('studio-collaborate'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.collabTitle, style: Puls3Text.h3),
            const SizedBox(height: Puls3Spacing.xs),
            Text(l10n.collabLead, style: Puls3Text.bodyMuted),
            const SizedBox(height: Puls3Spacing.lg),
            if (hireId == null)
              AgentHireForm(
                wallet: wallet,
                agents: candidates,
                selected: selected,
                onAgentChanged: _select,
                instructionsController: _instructions,
                budgetController: _budget,
                busy: _hiring,
                error: _error,
                onCopyWallet: () => copyToClipboard(
                  context,
                  wallet ?? '',
                  message: l10n.collabWalletCopied,
                ),
                onOpenFaucet: () => _open(circleFaucetUrl),
                onHire: selected == null ? null : _hire,
              )
            else ...[
              AgentHireProgressView(
                hireId: hireId,
                steps: _steps(l10n),
                result: progress?.result,
                stopped: _stopped(l10n),
                onOpenTransaction: (url) => _open(Uri.parse(url)),
                onHireAgain: progress?.isFinal == true ? _reset : null,
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
          ],
        );
      },
    );
  }
}
