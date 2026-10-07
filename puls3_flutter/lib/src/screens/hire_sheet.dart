import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/hire_payment_view.dart';

/// Opens the hire and pay flow for [agent].
Future<void> showHireSheet(BuildContext context, Agent agent) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => HireSheet(agent: agent),
  );
}

/// Container for the hire flow: owns the phase and talks to the wallet.
class HireSheet extends StatefulWidget {
  const HireSheet({super.key, required this.agent});

  final Agent agent;

  @override
  State<HireSheet> createState() => _HireSheetState();
}

class _HireSheetState extends State<HireSheet> {
  HirePhase _phase = HirePhase.review;
  String? _errorMessage;

  Future<void> _confirm() async {
    final wallet = AppScope.of(context).wallet;
    setState(() {
      _phase = HirePhase.signing;
      _errorMessage = null;
    });

    try {
      if (wallet.address == null) {
        await wallet.connect();
      }
      // Demo signing: nothing is submitted. The real flow calls the server
      // relay (createHire, prepareFund, submitEscrowCall) once it exists.
      await wallet.signTransaction(
        'mock-usdc-payment:${widget.agent.stellarAddress}:'
        '${widget.agent.priceUsdcStroops}',
      );
      if (!mounted) return;
      setState(() => _phase = HirePhase.confirmed);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = HirePhase.error;
        _errorMessage = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Payment could not be completed';
      });
    }
  }

  void _backToMarketplace() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go('/market');
  }

  @override
  Widget build(BuildContext context) {
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
          child: HirePaymentView(
            phase: _phase,
            agentName: widget.agent.name,
            priceUsdcStroops: widget.agent.priceUsdcStroops,
            destinationAddress: widget.agent.stellarAddress,
            errorMessage: _errorMessage,
            onConfirm: _confirm,
            onRetry: _confirm,
            onBackToMarketplace: _backToMarketplace,
          ),
        ),
      ),
    );
  }
}
