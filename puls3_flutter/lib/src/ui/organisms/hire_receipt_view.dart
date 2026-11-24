import 'package:flutter/material.dart';

import '../../domain/stellar_explorer.dart';
import '../../domain/stellar_format.dart';
import '../../domain/usdc.dart';
import '../../hire/hire_gateway.dart';
import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/section_label.dart';
import '../molecules/key_value_row.dart';

/// A hire's subcontract receipt (#334, ADR-0011 D6): the reserve the
/// consumer funded, what completed subcontracts spent from it, and one row
/// per child job with its provider, the related-party disclosure, the
/// amounts, its state, the hired agent's justification and the explorer
/// links. Presentational: links are opened through [onOpenUrl].
class HireReceiptView extends StatelessWidget {
  const HireReceiptView({
    super.key,
    required this.reserveUsdcStroops,
    required this.lines,
    this.onOpenUrl,
  });

  /// The subcontract reserve funded with the hire, in USDC stroops.
  final int reserveUsdcStroops;

  /// The receipt lines, oldest first.
  final List<HireReceiptEntry> lines;

  /// Opens an explorer link.
  final ValueChanged<String>? onOpenUrl;

  /// Whether a hire with [reserveUsdcStroops] and [lines] has a receipt to
  /// show: a plain hire has neither.
  static bool shows({
    required int reserveUsdcStroops,
    required List<HireReceiptEntry> lines,
  }) => reserveUsdcStroops > 0 || lines.isNotEmpty;

  /// What completed subcontracts took from the reserve: their payout plus
  /// the platform fee.
  static int spentUsdcStroops(List<HireReceiptEntry> lines) => lines
      .where((line) => line.state == 'completed')
      .fold(
        0,
        (sum, line) =>
            sum + (line.payoutUsdcStroops ?? 0) + (line.feeUsdcStroops ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('hire-receipt'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.hireReceiptTitle),
        const SizedBox(height: Puls3Spacing.xs),
        KeyValueRow(
          label: l10n.hireReceiptReserve,
          value: _usdc(reserveUsdcStroops),
          valueWidget: _Amount(_usdc(reserveUsdcStroops)),
        ),
        KeyValueRow(
          key: const ValueKey('hire-receipt-spent'),
          label: l10n.hireReceiptSpent,
          value: _usdc(spentUsdcStroops(lines)),
          valueWidget: _Amount(_usdc(spentUsdcStroops(lines))),
        ),
        Text(l10n.hireSubcontractRefundNote, style: Puls3Text.bodyMuted),
        const SizedBox(height: Puls3Spacing.sm),
        if (lines.isEmpty)
          Text(
            l10n.hireReceiptEmpty,
            key: const ValueKey('hire-receipt-empty'),
            style: Puls3Text.bodyMuted,
          )
        else
          for (final line in lines) ...[
            _ReceiptLineRow(line: line, onOpenUrl: onOpenUrl),
            const SizedBox(height: Puls3Spacing.sm),
          ],
      ],
    );
  }
}

String _usdc(int stroops) => '${formatUsdc(stroops)} USDC';

/// A USDC amount in mono type.
class _Amount extends StatelessWidget {
  const _Amount(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: Puls3Text.data);
}

/// The localized name of a receipt line state; an unknown one is shown raw.
String hireReceiptStateLabel(AppLocalizations l10n, String state) =>
    switch (state) {
      'pending' => l10n.hireReceiptStatePending,
      'not_opened' => l10n.hireReceiptStateNotOpened,
      'unverified' => l10n.hireReceiptStateUnverified,
      'open' => l10n.hireReceiptStateOpen,
      'funded' => l10n.hireReceiptStateFunded,
      'submitted' => l10n.hireReceiptStateSubmitted,
      'completed' => l10n.hireReceiptStateCompleted,
      'rejected' => l10n.hireReceiptStateRejected,
      'expired' => l10n.hireReceiptStateExpired,
      _ => state,
    };

class _ReceiptLineRow extends StatelessWidget {
  const _ReceiptLineRow({required this.line, this.onOpenUrl});

  final HireReceiptEntry line;
  final ValueChanged<String>? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = line.id;
    final fee = line.feeUsdcStroops;
    final payout = line.payoutUsdcStroops;
    final opened = _url(line.createExplorerUrl, line.createTransaction);
    final settled = _url(line.settleExplorerUrl, line.settleTransaction);
    return Container(
      key: ValueKey('hire-receipt-line-$id'),
      padding: const EdgeInsets.all(Puls3Spacing.md),
      decoration: BoxDecoration(
        color: Puls3Colors.background,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Puls3Spacing.xs,
            runSpacing: Puls3Spacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.hireReceiptProvider(line.providerAgentId),
                style: Puls3Text.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(shortenAddress(line.providerWallet), style: Puls3Text.data),
              if (line.relatedParty)
                _Badge(
                  key: ValueKey('hire-receipt-related-$id'),
                  label: l10n.hireReceiptRelatedParty,
                  semanticsLabel: l10n.hireReceiptRelatedPartyHint,
                  color: Puls3Colors.accent,
                ),
              _Badge(
                key: ValueKey('hire-receipt-state-$id'),
                label: hireReceiptStateLabel(l10n, line.state),
                color: Puls3Colors.lavender,
              ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xs),
          KeyValueRow(
            label: l10n.hireReceiptBudget,
            value: _usdc(line.budgetUsdcStroops),
            valueWidget: _Amount(_usdc(line.budgetUsdcStroops)),
          ),
          if (fee != null)
            KeyValueRow(
              key: ValueKey('hire-receipt-fee-$id'),
              label: l10n.hireReceiptFee,
              value: _usdc(fee),
              valueWidget: _Amount(_usdc(fee)),
            ),
          if (payout != null)
            KeyValueRow(
              key: ValueKey('hire-receipt-payout-$id'),
              label: l10n.hireReceiptPayout,
              value: _usdc(payout),
              valueWidget: _Amount(_usdc(payout)),
            ),
          const SizedBox(height: Puls3Spacing.xs),
          Text(l10n.hireReceiptJustification, style: Puls3Text.caption),
          Text(line.justification, style: Puls3Text.body),
          if (opened != null || settled != null) ...[
            const SizedBox(height: Puls3Spacing.xs),
            Wrap(
              spacing: Puls3Spacing.sm,
              children: [
                if (opened != null)
                  _ExplorerLink(
                    key: ValueKey('hire-receipt-opened-$id'),
                    label: l10n.hireReceiptOpened,
                    url: opened,
                    onOpenUrl: onOpenUrl,
                  ),
                if (settled != null)
                  _ExplorerLink(
                    key: ValueKey('hire-receipt-settled-$id'),
                    label: l10n.hireReceiptSettled,
                    url: settled,
                    onOpenUrl: onOpenUrl,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The server's explorer link, else one built from [hash]; null without a
  /// hash.
  static String? _url(String? serverUrl, String? hash) =>
      hash == null ? null : serverUrl ?? stellarExpertTxUrl(hash);
}

class _Badge extends StatelessWidget {
  const _Badge({
    super.key,
    required this.label,
    required this.color,
    this.semanticsLabel,
  });

  final String label;
  final Color color;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Puls3Spacing.xs,
        vertical: Puls3Spacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: color),
      ),
      child: Text(label, style: Puls3Text.caption.copyWith(color: color)),
    );
    final semanticsLabel = this.semanticsLabel;
    if (semanticsLabel == null) return badge;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: badge,
    );
  }
}

class _ExplorerLink extends StatelessWidget {
  const _ExplorerLink({
    super.key,
    required this.label,
    required this.url,
    this.onOpenUrl,
  });

  final String label;
  final String url;
  final ValueChanged<String>? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final open = onOpenUrl;
    return Semantics(
      link: true,
      hint: context.l10n.hireReceiptExplorerHint,
      child: TextButton.icon(
        onPressed: open == null ? null : () => open(url),
        icon: const Icon(Icons.open_in_new_rounded, size: 16),
        label: Text(label),
      ),
    );
  }
}
