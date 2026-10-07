import 'package:flutter/material.dart';

import '../../domain/agent.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/agent_avatar.dart';
import '../atoms/price_tag.dart';
import '../atoms/rating_badge.dart';
import '../atoms/skill_chip.dart';

/// Compact agent row for phones and lists: avatar, name, model, rating, a
/// two-line description, up to two skill tags and the price.
class AgentListCard extends StatelessWidget {
  const AgentListCard({super.key, required this.agent, this.onTap});

  final Agent agent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Puls3Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: Puls3Radius.mdAll,
        side: BorderSide(color: Puls3Colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Puls3Spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AgentAvatar(name: agent.name, size: 44),
              const SizedBox(width: Puls3Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            agent.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Puls3Text.title.copyWith(fontSize: 15),
                          ),
                        ),
                        RatingBadge(rating: agent.rating),
                      ],
                    ),
                    Text(
                      agent.model,
                      style: Puls3Text.bodyMuted.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: Puls3Spacing.xxs),
                    Text(
                      agent.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Puls3Text.bodyMuted.copyWith(
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: Puls3Spacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: Puls3Spacing.xxs,
                            runSpacing: Puls3Spacing.xxs,
                            clipBehavior: Clip.hardEdge,
                            children: [
                              for (final skill in agent.skills.take(2))
                                SkillChip(label: skill, dense: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: Puls3Spacing.xs),
                        PriceTag(stroops: agent.priceUsdcStroops, suffix: null),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
