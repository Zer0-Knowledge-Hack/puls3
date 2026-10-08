import 'package:flutter/material.dart';

import '../../domain/agent.dart';
import '../../theme/breakpoints.dart';
import '../../theme/puls3_theme.dart';
import '../molecules/agent_card.dart';
import '../molecules/agent_card_skeleton.dart';

/// Responsive grid of [AgentCard]s.
class AgentGrid extends StatelessWidget {
  const AgentGrid({super.key, required this.agents, required this.onSelect});

  final List<Agent> agents;
  final ValueChanged<Agent> onSelect;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveWrap(
      children: [
        for (final agent in agents)
          AgentCard(
            key: ValueKey(agent.id),
            name: agent.name,
            topSkill: agent.topSkill,
            priceUsdcStroops: agent.priceUsdcStroops,
            rating: agent.rating,
            description: agent.description,
            model: agent.model,
            onTap: () => onSelect(agent),
          ),
      ],
    );
  }
}

/// The grid while the catalog loads: [count] [AgentCardSkeleton]s.
class AgentGridSkeleton extends StatelessWidget {
  const AgentGridSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading agents',
      child: _ResponsiveWrap(
        children: List.generate(count, (_) => const AgentCardSkeleton()),
      ),
    );
  }
}

/// One, two or three columns, by the available width.
class _ResponsiveWrap extends StatelessWidget {
  const _ResponsiveWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= Puls3Breakpoints.gridThreeColumns
            ? 3
            : width >= Puls3Breakpoints.compact
            ? 2
            : 1;
        const gap = Puls3Spacing.md;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: cardWidth, child: child),
          ],
        );
      },
    );
  }
}
