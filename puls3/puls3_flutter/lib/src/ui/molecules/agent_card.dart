import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/agent_avatar.dart';
import '../atoms/price_tag.dart';
import '../atoms/rating_badge.dart';
import '../atoms/skill_chip.dart';

/// Marketplace card for a single agent. Purely presentational.
class AgentCard extends StatefulWidget {
  const AgentCard({
    super.key,
    required this.name,
    required this.topSkill,
    required this.priceUsdcStroops,
    required this.rating,
    this.description,
    this.model,
    this.onTap,
    this.highlighted = false,
  });

  final String name;
  final String topSkill;
  final int priceUsdcStroops;
  final double rating;
  final String? description;
  final String? model;
  final VoidCallback? onTap;

  /// Draws an accent border, e.g. for a live preview.
  final bool highlighted;

  @override
  State<AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<AgentCard> {
  // Hover is purely visual, so it is fine to keep locally.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.highlighted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: Puls3Durations.fast,
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.lgAll,
          border: Border.all(
            color: active ? Puls3Colors.accent : Puls3Colors.border,
          ),
        ),
        child: Material(
          color: Puls3Colors.transparent,
          borderRadius: Puls3Radius.lgAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(Puls3Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                              widget.name.isEmpty
                                  ? 'Untitled agent'
                                  : widget.name,
                              style: Puls3Text.titleMd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.model != null)
                              Text(
                                widget.model!,
                                style: Puls3Text.label.copyWith(
                                  color: Puls3Colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      RatingBadge(rating: widget.rating),
                    ],
                  ),
                  if (widget.description != null) ...[
                    const SizedBox(height: Puls3Spacing.sm),
                    Text(
                      widget.description!,
                      style: Puls3Text.bodyMuted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: Puls3Spacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SkillChip(label: widget.topSkill),
                        ),
                      ),
                      const SizedBox(width: Puls3Spacing.sm),
                      PriceTag(
                        stroops: widget.priceUsdcStroops,
                        suffix: null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
