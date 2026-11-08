import 'dart:async';

import 'package:flutter/material.dart';
import 'package:puls3_domain/puls3_domain.dart' show feedbackCommentMaxLength;

import '../hire/hire_flow_controller.dart' show walletErrorMessage;
import '../hire/hire_gateway.dart';
import '../l10n/l10n.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/organisms/rate_sheet_view.dart';
import '../wallet/wallet_port.dart';

/// Opens S10 over S06 for [hire], which [consumer] hired. Completes with
/// the score once the rating is relayed, or null when the sheet is closed
/// without one.
Future<int?> showRateHireSheet(
  BuildContext context, {
  required HireProgress hire,
  required String consumer,
}) {
  return showModalBottomSheet<int>(
    context: context,
    // Above the whole app, so the phone's bottom navigation bar does not
    // cover the end of the sheet.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Puls3Colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(Puls3Radius.lg),
      ),
    ),
    builder: (sheetContext) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Puls3Spacing.lg,
        Puls3Spacing.lg,
        Puls3Spacing.lg,
        Puls3Spacing.lg + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: RateHireSheet(hire: hire, consumer: consumer),
    ),
  );
}

/// S10 (flow F7): the container. It checks that the connected wallet is
/// [consumer], then the wallet signs the `give_feedback` the server
/// prepared, unchanged, and the server relays it. The sheet closes with the
/// score; S06 polls the hire until the rating is confirmed.
class RateHireSheet extends StatefulWidget {
  const RateHireSheet({super.key, required this.hire, required this.consumer});

  final HireProgress hire;

  /// The wallet that hired: the only one allowed to rate.
  final String consumer;

  @override
  State<RateHireSheet> createState() => _RateHireSheetState();
}

class _RateHireSheetState extends State<RateHireSheet> {
  final _comment = TextEditingController();
  int? _score;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final score = _score;
    if (score == null || _sending) return;
    final l10n = context.l10n;
    final scope = AppScope.of(context);
    final wallet = scope.wallet;
    final address = wallet.address;
    if (address != widget.consumer) {
      setState(() => _error = l10n.rateWrongWallet);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final gateway = scope.hireGateway;
    final hireId = widget.hire.hireId;
    try {
      await gateway.ensureSignedIn(address!, wallet.signChallenge);
      final preparation = await gateway.prepareFeedback(
        hireId,
        score,
        _comment.text.trim(),
      );
      final signed = await wallet.signTransaction(
        preparation.unsignedTransaction,
      );
      await gateway.submitFeedback(hireId, preparation, signed);
      if (!mounted) return;
      Navigator.of(context).pop(score);
    } on WalletException catch (e) {
      _fail(
        e is WalletSignatureRejected ? l10n.rateNotSent : walletErrorMessage(e),
      );
    } on HireGatewayException catch (e) {
      _fail(switch (e) {
        HireAlreadyRated() => l10n.rateAlreadyRated,
        HireWrongWallet() => l10n.rateWrongWallet,
        HireNotRatable() => l10n.rateNotCompleted,
        HireOwnerCannotRate() => l10n.rateOwnerCannotRate,
        HireInvalidRating() => l10n.rateInvalid(feedbackCommentMaxLength),
        HireRatingInProgress() => l10n.rateInProgress,
        HireRatingOutcomeUnknown() => l10n.rateOutcomeUnknown,
        _ => e.message,
      });
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RateSheetView(
      agentName: widget.hire.agentName,
      score: _score,
      commentController: _comment,
      sending: _sending,
      error: _error,
      isDemo: AppScope.of(context).hireGateway.isDemo,
      onScore: (score) => setState(() {
        _score = score;
        _error = null;
      }),
      onSend: () => unawaited(_send()),
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
