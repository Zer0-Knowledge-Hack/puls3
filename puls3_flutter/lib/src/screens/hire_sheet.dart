import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/agent.dart';
import '../domain/stellar_explorer.dart';
import '../domain/usdc.dart';
import '../hire/hire_flow_controller.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../state/wallet_controller.dart';
import '../studio/studio_gateway.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/copy_to_clipboard.dart';
import '../ui/atoms/primary_button.dart';
import '../ui/organisms/agent_hire_panel.dart';
import '../ui/organisms/hire_payment_view.dart';
import '../ui/organisms/hire_subcontract_section.dart';
import '../ui/organisms/wallet_panel.dart' show signInNotice;
import '../wallet/wallet_port.dart' show WalletException;
import 'agent_hire_tracker.dart';

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
///
/// When the connected wallet owns live Studio agents, it first asks who
/// pays: the wallet (the flow above) or one of those agents, which pays from
/// its own wallet through `StudioEndpoint.hireAgentAs` (#312).
class HireSheet extends StatefulWidget {
  const HireSheet({super.key, required this.agent, this.openUrl = _launch});

  final Agent agent;

  /// Opens the explorer; replaceable in tests.
  final Future<void> Function(Uri url) openUrl;

  @override
  State<HireSheet> createState() => _HireSheetState();
}

/// One of the user's live Studio agents, which can pay a hire from its own
/// wallet.
class _PayingAgent {
  const _PayingAgent({required this.registryId, required this.name});

  final int registryId;
  final String name;
}

/// The subcontract part of the form as the sheet reads it (#334).
class _SubcontractForm {
  const _SubcontractForm({
    required this.shown,
    required this.locked,
    required this.reserve,
    required this.typed,
    this.error,
  });

  /// The section is shown: the agent offers a reserve, or the started hire
  /// has one.
  final bool shown;

  /// The hire was started: its reserve and flag are fixed.
  final bool locked;

  /// The reserve to fund, in USDC stroops; 0 while [error] is set.
  final int reserve;

  /// What the consumer typed, in USDC stroops, even when it cannot be
  /// funded.
  final int typed;
  final String? error;
}

class _HireSheetState extends State<HireSheet> {
  final _input = TextEditingController();

  /// The subcontract reserve, in USDC (#334).
  final _reserve = TextEditingController();
  bool _reservePrefilled = false;
  bool _allowRelatedParty = true;

  /// "A completed subcontract is paid even if you reject the result."
  bool _subcontractConsent = false;
  HireFlowController? _flow;

  /// The user's live agents that can pay instead of the user's wallet.
  List<_PayingAgent> _payingAgents = const [];

  /// Who pays: null is the user's wallet (the default flow).
  _PayingAgent? _payer;

  /// The wallet that owns [_payingAgents].
  String? _owner;
  bool _agentHiring = false;
  String? _agentError;
  AgentHireStart? _agentHire;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    if (_flow == null) {
      final flow = _flow = HireFlowController(
        agent: widget.agent,
        gateway: scope.hireGateway,
        wallet: scope.wallet,
        store: scope.hireFlowStore,
      );
      flow.addListener(_showResumedTask);
      // A connected wallet: offer to resume an unfinished hire right away.
      final consumer = scope.wallet.address;
      if (consumer != null) flow.restore(consumer);
      _showResumedTask();
      _wallet = scope.wallet..addListener(_onWallet);
      unawaited(_loadSessionData());
    }
  }

  WalletController? _wallet;

  /// The wallet whose session the terms and paying agents were read with.
  String? _loadedFor;

  /// A wallet that connects (and so signs in) while the sheet is open.
  void _onWallet() {
    final address = _wallet?.address;
    if (address != null && address != _loadedFor) {
      unawaited(_loadSessionData());
    }
  }

  /// Reads what needs the server session: the reserve terms and the user's
  /// paying agents. Without a session it reads nothing and never opens a
  /// wallet prompt (#334 T8.2); the sheet still hires as a plain hire.
  Future<void> _loadSessionData() async {
    final wallet = _wallet;
    final flow = _flow;
    if (wallet == null || flow == null || !await wallet.hasSession()) return;
    if (!mounted) return;
    final consumer = wallet.address;
    // The wallet listener and the confirm may both ask: read once.
    final pending = _sessionLoad;
    if (consumer == _loadedFor && pending != null) return pending;
    _loadedFor = consumer;
    return _sessionLoad = Future.wait([
      flow.loadTerms(),
      if (consumer != null) _loadPayingAgents(consumer),
    ]).then((_) {});
  }

  Future<void>? _sessionLoad;

  @override
  void dispose() {
    _wallet?.removeListener(_onWallet);
    _flow?.dispose();
    _input.dispose();
    _reserve.dispose();
    super.dispose();
  }

  /// Shows the task, the reserve and the flag of the unfinished hire this
  /// sheet resumes, or prefills the reserve once the terms are read.
  void _showResumedTask() {
    final flow = _flow;
    if (flow == null) return;
    final task = flow.resumedInput;
    if (task != null && _input.text != task) _input.text = task;
    if (!flow.canEditTask) {
      final reserve = flow.subcontractReserve;
      if (parseUsdcToStroops(_reserve.text) != reserve) {
        _reserve.text = formatUsdc(reserve);
      }
      _allowRelatedParty = flow.allowRelatedParty;
    } else if (!_reservePrefilled && flow.terms.offered) {
      _reservePrefilled = true;
      _reserve.text = formatUsdc(flow.terms.prefillStroops);
    }
  }

  _SubcontractForm _subcontract(HireFlowController flow) {
    final terms = flow.terms;
    if (!flow.canEditTask) {
      final reserve = flow.subcontractReserve;
      return _SubcontractForm(
        shown: reserve > 0,
        locked: true,
        reserve: reserve,
        typed: reserve,
      );
    }
    if (!terms.offered) {
      return const _SubcontractForm(
        shown: false,
        locked: false,
        reserve: 0,
        typed: 0,
      );
    }
    final text = _reserve.text.trim();
    final typed = text.isEmpty ? 0 : parseUsdcToStroops(text);
    if (typed == null || !terms.allows(typed)) {
      return _SubcontractForm(
        shown: true,
        locked: false,
        reserve: 0,
        typed: typed ?? 0,
        error: context.l10n.hireSubcontractReserveInvalid(
          formatUsdc(terms.reserveMaxStroops),
        ),
      );
    }
    return _SubcontractForm(
      shown: true,
      locked: false,
      reserve: typed,
      typed: typed,
    );
  }

  int? get _hiredAgentId =>
      widget.agent.registryId ?? int.tryParse(widget.agent.id);

  /// The connected wallet's live Studio agents, as "My agents" lists them:
  /// deployed drafts with a registry id. The agent being hired is left out.
  Future<void> _loadPayingAgents(String owner) async {
    final hired = _hiredAgentId;
    if (hired == null) return;
    final gateway = AppScope.of(context).studioGateway;
    try {
      final drafts = await gateway.listDrafts(owner: owner);
      if (!mounted) return;
      final agents = <_PayingAgent>[];
      for (final draft in drafts) {
        if (draft.deployState != DraftDeployState.live) continue;
        final id = int.tryParse(draft.agentId ?? '');
        if (id == null || id == hired) continue;
        agents.add(_PayingAgent(registryId: id, name: draft.name));
      }
      setState(() {
        _owner = owner;
        _payingAgents = agents;
      });
    } catch (_) {
      // Without the list the user still pays with the wallet, as before.
    }
  }

  String? _payerWallet(_PayingAgent payer) {
    if (_agentHire case final started?) return started.hiringWallet;
    for (final agent in AppScope.of(context).catalog.agents) {
      if (agent.registryId == payer.registryId ||
          agent.id == '${payer.registryId}') {
        return agent.stellarAddress;
      }
    }
    return null;
  }

  Future<void> _hireAsAgent(_PayingAgent payer) async {
    final l10n = context.l10n;
    final owner = _owner;
    final hired = _hiredAgentId;
    final input = _input.text.trim();
    if (owner == null || hired == null) return;
    if (input.isEmpty) {
      setState(() => _agentError = l10n.hireAsAgentInputMissing);
      return;
    }
    setState(() {
      _agentHiring = true;
      _agentError = null;
    });
    try {
      final started = await AppScope.of(context).studioGateway.hireAgentAs(
        hiringAgentId: payer.registryId,
        agentId: hired,
        input: input,
        budgetUsdcStroops: widget.agent.priceUsdcStroops,
        owner: owner,
      );
      if (!mounted) return;
      setState(() {
        _agentHiring = false;
        _agentHire = started;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agentHiring = false;
        _agentError = agentHireErrorMessage(l10n, e);
      });
    }
  }

  void _run() {
    // A second tap while the sign-in prompt is open must not open another.
    if (_confirming) return;
    _confirming = true;
    unawaited(_confirm().whenComplete(() => _confirming = false));
  }

  bool _confirming = false;

  /// Confirms the hire. Without a session it first connects and signs in,
  /// then reads the terms: when they offer a reserve the user has not seen
  /// yet, it stops so the reserve is reviewed before anything is paid.
  Future<void> _confirm() async {
    final flow = _flow!;
    final wallet = _wallet;
    if (wallet != null && flow.canEditTask && !await wallet.hasSession()) {
      final offeredBefore = flow.terms.offered;
      try {
        // Connecting signs in: one prompt. A server failure leaves no
        // session, and the hire's own sign-in reports it.
        await wallet.connect();
      } on WalletException {
        // Declined or failed: the wallet state shows why; nothing started.
        return;
      }
      await _loadSessionData();
      if (!mounted) return;
      if (!offeredBefore && flow.terms.offered) return;
    }
    if (!mounted) return;
    final subcontract = _subcontract(flow);
    await flow.run(
      _input.text.trim(),
      subcontractReserve: subcontract.reserve,
      allowRelatedParty: _allowRelatedParty,
    );
  }

  void _backToMarketplace() => _leaveTo('/market');

  void _leaveTo(String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(location);
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
              listenable: Listenable.merge([flow, _reserve]),
              builder: (context, _) {
                final payer = _payer;
                // The choice is offered before anything is signed or paid.
                final canChoose =
                    _payingAgents.isNotEmpty &&
                    _agentHire == null &&
                    !_agentHiring &&
                    flow.step == HireStep.review &&
                    flow.hireId == null &&
                    !flow.isRunning;
                final body = payer == null
                    ? _walletPayment(flow)
                    : _agentPayment(payer);
                if (!canChoose) return body;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _payerChoice(context),
                    const SizedBox(height: Puls3Spacing.lg),
                    body,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _payerChoice(BuildContext context) {
    final l10n = context.l10n;
    Widget option({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? Puls3Colors.accent : Puls3Colors.muted,
      ),
      title: Text(label, style: Puls3Text.body),
      selected: selected,
      onTap: onTap,
    );
    return Column(
      key: const Key('hire-payer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.hirePayerTitle, style: Puls3Text.title),
        option(
          key: const Key('hire-payer-you'),
          label: l10n.hirePayerYou,
          selected: _payer == null,
          onTap: () => setState(() {
            _payer = null;
            _agentError = null;
          }),
        ),
        for (final agent in _payingAgents)
          option(
            key: Key('hire-payer-agent-${agent.registryId}'),
            label: l10n.hirePayerAgent(agent.name),
            selected: _payer == agent,
            onTap: () => setState(() {
              _payer = agent;
              _agentError = null;
            }),
          ),
      ],
    );
  }

  /// The user's agent pays from its own wallet: no wallet signature.
  Widget _agentPayment(_PayingAgent payer) {
    final l10n = context.l10n;
    final started = _agentHire;
    final owner = _owner;
    if (started != null && owner != null) {
      return AgentHireTracker(
        hiringAgentId: payer.registryId,
        hireId: started.hireId,
        owner: owner,
        openUrl: widget.openUrl,
      );
    }
    final wallet = _payerWallet(payer);
    return Column(
      key: const Key('hire-as-agent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.hireAgent(widget.agent.name), style: Puls3Text.h3),
        const SizedBox(height: Puls3Spacing.xs),
        Text(
          l10n.hireAsAgentLead(
            payer.name,
            formatUsdc(widget.agent.priceUsdcStroops),
          ),
          style: Puls3Text.bodyMuted,
        ),
        const SizedBox(height: Puls3Spacing.md),
        AgentWalletCard(
          wallet: wallet,
          onCopyWallet: () => copyToClipboard(
            context,
            wallet ?? '',
            message: l10n.collabWalletCopied,
          ),
          onOpenFaucet: () => unawaited(widget.openUrl(circleFaucetUrl)),
        ),
        const SizedBox(height: Puls3Spacing.md),
        TextField(
          key: const ValueKey('hire-input'),
          controller: _input,
          enabled: !_agentHiring,
          minLines: 2,
          maxLines: 4,
          style: Puls3Text.body,
          decoration: InputDecoration(
            labelText: l10n.hireTaskLabel,
            hintText: l10n.hireTaskHint,
          ),
        ),
        if (_agentError case final message?) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(
            message,
            key: const Key('collab-error'),
            style: Puls3Text.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Puls3Spacing.md),
        PrimaryButton(
          key: const Key('hire-as-agent-confirm'),
          label: _agentHiring
              ? l10n.hireAsAgentHiring
              : l10n.hireAsAgentConfirm(payer.name),
          icon: Icons.handshake_outlined,
          isLoading: _agentHiring,
          expand: true,
          onPressed: _agentHiring ? null : () => unawaited(_hireAsAgent(payer)),
        ),
      ],
    );
  }

  Widget _walletPayment(HireFlowController flow) {
    final hash = flow.payment?.transactionHash;
    final subcontract = _subcontract(flow);
    // Policy 1: a new hire with a reserve needs the consent; a started one
    // already had it.
    final needsConsent = !subcontract.locked && subcontract.typed > 0;
    final terms = flow.terms;
    return HirePaymentView(
      subcontractSection: subcontract.shown
          ? HireSubcontractSection(
              maxChildren: terms.maxChildren,
              reserveMaxStroops: max(
                terms.reserveMaxStroops,
                subcontract.reserve,
              ),
              reserveController: _reserve,
              reserveError: subcontract.error,
              allowRelatedParty: _allowRelatedParty,
              onAllowRelatedPartyChanged: (value) =>
                  setState(() => _allowRelatedParty = value),
              showConsent: needsConsent,
              consented: _subcontractConsent,
              onConsentChanged: (value) =>
                  setState(() => _subcontractConsent = value),
              locked: subcontract.locked,
              enabled: !flow.isRunning,
            )
          : null,
      reserveUsdcStroops: subcontract.reserve,
      canConfirm:
          subcontract.error == null && (!needsConsent || _subcontractConsent),
      phase: _phase(flow),
      agentName: widget.agent.name,
      priceUsdcStroops: widget.agent.priceUsdcStroops,
      destinationAddress: widget.agent.stellarAddress,
      isDemo: flow.isDemo,
      inputController: _input,
      inputLocked: !flow.canEditTask,
      resumeNote: flow.resumedInput == null
          ? null
          : 'You have an unfinished hire with this agent. '
                'Confirming resumes it, so you are never charged '
                'twice.',
      progressLabel: _progress(flow.step),
      errorMessage: flow.error,
      hireId: flow.hireId,
      transactionHash: hash,
      paymentConfirmed: flow.payment?.isConfirmed ?? false,
      onConfirm: _run,
      onRetry: _run,
      onBackToMarketplace: _backToMarketplace,
      onViewHire: flow.hireId == null
          ? null
          : () => _leaveTo('/hires/${flow.hireId}'),
      onMyHires: flow.hireId == null ? null : () => _leaveTo('/hires'),
      onOpenExplorer: hash == null || hash.isEmpty
          ? null
          : () => unawaited(widget.openUrl(Uri.parse(_explorerUrl(flow)))),
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
    HireStep.signingIn => signInNotice('Your wallet'),
    HireStep.creating => 'Creating the hire…',
    HireStep.signingCreateJob => 'Sign the escrow job in your wallet (1 of 2).',
    HireStep.submittingCreateJob => 'Creating the escrow job on Stellar…',
    HireStep.preparingFund => 'Waiting for the escrow job to confirm…',
    HireStep.signingFund => 'Sign the payment in your wallet (2 of 2).',
    HireStep.submittingFund => 'Sending the payment to the escrow…',
    HireStep.review || HireStep.done => null,
  };
}
