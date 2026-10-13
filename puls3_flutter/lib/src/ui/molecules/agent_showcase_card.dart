import 'package:flutter/material.dart';

import '../../domain/usdc.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/agent_avatar.dart';

/// A rich agent card for showcases (the landing page): identity, network,
/// what it does, its skills, three key figures and two actions. Purely
/// presentational.
class AgentShowcaseCard extends StatefulWidget {
  const AgentShowcaseCard({
    super.key,
    required this.name,
    required this.model,
    required this.description,
    required this.skills,
    required this.priceUsdcStroops,
    required this.rating,
    required this.registryId,
    required this.onDetails,
    required this.onHire,
  });

  final String name;
  final String model;
  final String description;
  final List<String> skills;
  final int priceUsdcStroops;

  /// 0 when the agent has no reviews yet.
  final double rating;

  /// The id in the Identity Registry; null for a demo agent.
  final int? registryId;
  final VoidCallback onDetails;
  final VoidCallback onHire;

  @override
  State<AgentShowcaseCard> createState() => _AgentShowcaseCardState();
}

class _AgentShowcaseCardState extends State<AgentShowcaseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rating = widget.rating > 0 ? widget.rating.toStringAsFixed(1) : '—';
    final id = widget.registryId;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Puls3Durations.fast,
        decoration: BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.lgAll,
          border: Border.all(
            color: _hovered
                ? Puls3Colors.accent.withValues(alpha: 0.7)
                : Puls3Colors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Puls3Spacing.md,
                Puls3Spacing.md,
                Puls3Spacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AgentAvatar(name: widget.name),
                      const SizedBox(width: Puls3Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: Puls3Text.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.model,
                              style: Puls3Text.caption.copyWith(
                                color: Puls3Colors.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const _NetworkBadge(),
                    ],
                  ),
                  const SizedBox(height: Puls3Spacing.sm),
                  SizedBox(
                    // Two lines, always: cards in a row keep one height.
                    height: 42,
                    child: Text(
                      widget.description,
                      style: Puls3Text.bodyMuted.copyWith(
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: Puls3Spacing.sm),
                  Wrap(
                    spacing: Puls3Spacing.xxs,
                    runSpacing: Puls3Spacing.xxs,
                    children: [
                      for (final skill in widget.skills.take(3))
                        _Tag(label: skill),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Puls3Spacing.md),
            const Divider(height: 1, color: Puls3Colors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Puls3Spacing.md,
                vertical: Puls3Spacing.sm,
              ),
              child: Row(
                children: [
                  _Figure(
                    label: 'Price / task',
                    value: '${formatUsdc(widget.priceUsdcStroops)} USDC',
                    accent: true,
                  ),
                  _Figure(label: 'Rating', value: rating),
                  _Figure(
                    label: 'On-chain id',
                    value: id == null ? 'Demo' : '#$id',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Puls3Colors.hairline),
            Padding(
              padding: const EdgeInsets.all(Puls3Spacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Puls3Colors.text,
                        side: const BorderSide(color: Puls3Colors.hairline),
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Details'),
                    ),
                  ),
                  const SizedBox(width: Puls3Spacing.xs),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onHire,
                      style: FilledButton.styleFrom(
                        backgroundColor: Puls3Colors.accent,
                        foregroundColor: Puls3Colors.onAccent,
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Hire'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.pillAll,
        border: Border.all(color: Puls3Colors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 6, color: Puls3Colors.success),
          const SizedBox(width: 4),
          Text(
            'Testnet',
            style: Puls3Text.caption.copyWith(
              color: Puls3Colors.success,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Puls3Colors.background,
        borderRadius: Puls3Radius.pillAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Text(label, style: Puls3Text.caption.copyWith(fontSize: 11)),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Puls3Text.caption.copyWith(
              color: Puls3Colors.muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Puls3Text.data.copyWith(
              fontSize: 13,
              color: accent ? Puls3Colors.accent : Puls3Colors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
