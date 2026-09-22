import 'package:flutter/material.dart';

import '../../domain/agent.dart';
import '../../theme/puls3_theme.dart';
import '../molecules/agent_card.dart';

/// Responsive grid of [AgentCard]s.
class AgentGrid extends StatelessWidget {
  const AgentGrid({super.key, required this.agents, required this.onSelect});

  final List<Agent> agents;
  final ValueChanged<Agent> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 3
            : width >= 640
            ? 2
            : 1;
        const gap = Puls3Spacing.md;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final agent in agents)
              SizedBox(
                width: cardWidth,
                child: AgentCard(
                  key: ValueKey(agent.id),
                  name: agent.name,
                  topSkill: agent.topSkill,
                  priceUsdcStroops: agent.priceUsdcStroops,
                  rating: agent.rating,
                  description: agent.description,
                  model: agent.model,
                  onTap: () => onSelect(agent),
                ),
              ),
          ],
        );
      },
    );
  }
}
