import 'package:flutter/material.dart';

import '../../domain/usdc.dart';
import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';

/// The subcontract part of the hire form (#334, ADR-0011): the reserve the
/// consumer funds beside the price, whether the agent may subcontract an
/// agent of the same owner, and the consent that a completed subcontract is
/// paid even if the result is rejected (Policy 1). Presentational: the
/// container owns the values and validates the reserve.
class HireSubcontractSection extends StatelessWidget {
  const HireSubcontractSection({
    super.key,
    required this.maxChildren,
    required this.reserveMaxStroops,
    required this.reserveController,
    required this.allowRelatedParty,
    required this.onAllowRelatedPartyChanged,
    required this.consented,
    required this.onConsentChanged,
    this.reserveError,
    this.showConsent = false,
    this.locked = false,
    this.enabled = true,
  });

  /// How many agents one hire may subcontract.
  final int maxChildren;

  /// The platform ceiling of the reserve, in USDC stroops.
  final int reserveMaxStroops;

  /// The reserve the consumer typed, in USDC.
  final TextEditingController reserveController;

  /// Why the typed reserve cannot be funded; null when it can.
  final String? reserveError;

  final bool allowRelatedParty;
  final ValueChanged<bool> onAllowRelatedPartyChanged;

  /// Shown while the reserve is above 0: Confirm then needs it ticked.
  final bool showConsent;
  final bool consented;
  final ValueChanged<bool> onConsentChanged;

  /// The hire was started: the values are shown, not editable.
  final bool locked;

  /// False while the flow runs.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editable = enabled && !locked;
    final max = formatUsdc(reserveMaxStroops);
    // A Material, not a decorated box, so the list tiles paint their ink.
    return Material(
      key: const ValueKey('hire-subcontract'),
      color: Puls3Colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Puls3Radius.mdAll,
        side: const BorderSide(color: Puls3Colors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Puls3Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.hireSubcontractTitle, style: Puls3Text.title),
            if (maxChildren > 0) ...[
              const SizedBox(height: Puls3Spacing.xs),
              Text(
                l10n.hireSubcontractLead(maxChildren),
                style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
              ),
            ],
            const SizedBox(height: Puls3Spacing.md),
            TextField(
              key: const ValueKey('hire-subcontract-reserve'),
              controller: reserveController,
              enabled: enabled,
              readOnly: locked,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Puls3Text.body,
              decoration: InputDecoration(
                labelText: l10n.hireSubcontractReserveLabel,
                helperText: l10n.hireSubcontractReserveHelper(max),
                errorText: reserveError,
              ),
            ),
            const SizedBox(height: Puls3Spacing.sm),
            SwitchListTile(
              key: const ValueKey('hire-subcontract-related-party'),
              contentPadding: EdgeInsets.zero,
              value: allowRelatedParty,
              onChanged: editable ? onAllowRelatedPartyChanged : null,
              title: Text(
                l10n.hireSubcontractRelatedParty,
                style: Puls3Text.body,
              ),
              subtitle: Text(
                l10n.hireSubcontractRelatedPartyNotice,
                style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
              ),
            ),
            if (showConsent)
              CheckboxListTile(
                key: const ValueKey('hire-subcontract-consent'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: consented,
                onChanged: editable
                    ? (value) => onConsentChanged(value ?? false)
                    : null,
                title: Text(
                  l10n.hireSubcontractConsent,
                  style: Puls3Text.body.copyWith(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
