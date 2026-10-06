import 'package:flutter/material.dart';

import '../../domain/agent_draft.dart';
import '../../theme/puls3_theme.dart';

/// The rules every agent must meet before it can be deployed.
const agentPolicies = [
  (
    Icons.gavel_rounded,
    'Lawful and safe',
    'No illegal, harmful, hateful or deceptive tasks.',
  ),
  (
    Icons.badge_outlined,
    'No impersonation',
    'Do not pose as a real person, brand or another agent.',
  ),
  (
    Icons.fact_check_outlined,
    'Honest listing',
    'The description and price match what the agent really does.',
  ),
  (
    Icons.key_off_outlined,
    'Never ask for secrets',
    'Agents must not request seed phrases, secret keys or passwords.',
  ),
  (
    Icons.handshake_outlined,
    'You own the output',
    'Clients can reject a delivery and be refunded from escrow.',
  ),
  (
    Icons.science_outlined,
    'Testnet demo',
    'This build runs on Stellar Testnet. No real funds move.',
  ),
];

/// Live checklist of the manifest rules plus the policy agreement. Each row
/// turns green as soon as it is met, so the builder sees what is missing.
class PublishChecklist extends StatelessWidget {
  const PublishChecklist({
    super.key,
    required this.errors,
    required this.policyAccepted,
    required this.onPolicyChanged,
    required this.onReadPolicies,
    this.highlightMissing = false,
  });

  final Map<AgentDraftField, String> errors;
  final bool policyAccepted;
  final ValueChanged<bool> onPolicyChanged;
  final VoidCallback onReadPolicies;

  /// After a deploy attempt: unmet rows turn amber.
  final bool highlightMissing;

  static const _labels = {
    AgentDraftField.name: 'Name, 3–48 characters',
    AgentDraftField.description: 'Description, 10–280 characters',
    AgentDraftField.prompt: 'System prompt, at least 20 characters',
    AgentDraftField.skills: '1–5 skills',
    AgentDraftField.price: 'A price above 0 USDC',
  };

  @override
  Widget build(BuildContext context) {
    final done =
        AgentDraftField.values.where((f) => !errors.containsKey(f)).length +
        (policyAccepted ? 1 : 0);
    final total = AgentDraftField.values.length + 1;
    return Container(
      key: const ValueKey('publish-checklist'),
      padding: const EdgeInsets.all(Puls3Spacing.md),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(
          color: highlightMissing && done < total
              ? Puls3Colors.accent
              : Puls3Colors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ready to publish',
                  style: Puls3Text.title.copyWith(fontSize: 15),
                ),
              ),
              Text(
                '$done/$total',
                style: Puls3Text.data.copyWith(
                  color: done == total
                      ? Puls3Colors.success
                      : Puls3Colors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xs),
          ClipRRect(
            borderRadius: Puls3Radius.pillAll,
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 4,
              color: done == total ? Puls3Colors.success : Puls3Colors.accent,
              backgroundColor: Puls3Colors.hairline,
            ),
          ),
          const SizedBox(height: Puls3Spacing.xs),
          for (final field in AgentDraftField.values)
            _CheckRow(
              label: _labels[field]!,
              met: !errors.containsKey(field),
              highlight: highlightMissing,
            ),
          const Divider(height: Puls3Spacing.md),
          Row(
            children: [
              Checkbox(
                key: const Key('policy-checkbox'),
                value: policyAccepted,
                onChanged: (v) => onPolicyChanged(v ?? false),
                side: BorderSide(
                  color: highlightMissing && !policyAccepted
                      ? Puls3Colors.accent
                      : Puls3Colors.muted,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onPolicyChanged(!policyAccepted),
                  child: Text(
                    'I agree to the puls3 agent policies',
                    style: Puls3Text.body.copyWith(fontSize: 13),
                  ),
                ),
              ),
              TextButton(
                onPressed: onReadPolicies,
                child: const Text('Read'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.met,
    required this.highlight,
  });

  final String label;
  final bool met;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final missingColor = highlight ? Puls3Colors.accent : Puls3Colors.muted;
    return Semantics(
      label: '$label, ${met ? 'done' : 'missing'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: met ? Puls3Colors.success : missingColor,
            ),
            const SizedBox(width: Puls3Spacing.xs),
            Expanded(
              child: Text(
                label,
                style: Puls3Text.body.copyWith(
                  fontSize: 13,
                  color: met ? Puls3Colors.text : missingColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with the agent policies.
Future<void> showAgentPolicies(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Puls3Spacing.md,
        0,
        Puls3Spacing.md,
        Puls3Spacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Agent policies',
            style: Puls3Text.title.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(
            'Every agent on puls3 must follow these rules.',
            style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
          ),
          const SizedBox(height: Puls3Spacing.md),
          for (final (icon, title, body) in agentPolicies)
            Padding(
              padding: const EdgeInsets.only(bottom: Puls3Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: Puls3Colors.lavender),
                  const SizedBox(width: Puls3Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Puls3Text.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          body,
                          style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Puls3Spacing.xs),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
  );
}
