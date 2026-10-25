import 'package:flutter/material.dart';

import '../../domain/agent_filter.dart';
import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/primary_button.dart';
import '../atoms/section_label.dart';
import '../atoms/skill_chip.dart';

/// The Marketplace filters as a panel: sort order and skills, with Reset and
/// a "Show N agents" action. Purely presentational: the sheet that hosts it
/// owns the selection.
class MarketFilters extends StatelessWidget {
  const MarketFilters({
    super.key,
    required this.skills,
    required this.selectedSkills,
    required this.sort,
    required this.resultCount,
    required this.onToggleSkill,
    required this.onSort,
    required this.onReset,
    required this.onApply,
  });

  /// Every skill in the catalog.
  final List<String> skills;
  final Set<String> selectedSkills;
  final AgentSort sort;

  /// How many agents the current selection shows.
  final int resultCount;
  final ValueChanged<String> onToggleSkill;
  final ValueChanged<AgentSort> onSort;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final active = selectedSkills.length + (sort == AgentSort.featured ? 0 : 1);
    return Column(
      key: const Key('market-filters'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(context.l10n.marketFilters, style: Puls3Text.title),
            ),
            TextButton(
              key: const Key('market-filters-reset'),
              onPressed: active == 0 ? null : onReset,
              child: Text(context.l10n.marketReset),
            ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.sm),
        SectionLabel(context.l10n.marketSortBy),
        const SizedBox(height: Puls3Spacing.xs),
        Wrap(
          spacing: Puls3Spacing.xs,
          runSpacing: Puls3Spacing.xs,
          children: [
            for (final option in AgentSort.values)
              SkillChip(
                key: Key('market-sort-${option.name}'),
                label: option.l10nLabel(context.l10n),
                selected: option == sort,
                onTap: () => onSort(option),
              ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.md),
        SectionLabel(context.l10n.marketSkills),
        const SizedBox(height: Puls3Spacing.xs),
        Wrap(
          spacing: Puls3Spacing.xs,
          runSpacing: Puls3Spacing.xs,
          children: [
            for (final skill in skills)
              SkillChip(
                label: localizedSkillName(context.l10n, skill),
                selected: selectedSkills.contains(skill),
                onTap: () => onToggleSkill(skill),
              ),
          ],
        ),
        const SizedBox(height: Puls3Spacing.lg),
        PrimaryButton(
          key: const Key('market-filters-apply'),
          label: context.l10n.marketShowAgents(resultCount),
          expand: true,
          onPressed: onApply,
        ),
      ],
    );
  }
}

/// The active filters as removable chips, with Clear all. Purely
/// presentational.
class ActiveFilters extends StatelessWidget {
  const ActiveFilters({
    super.key,
    required this.selectedSkills,
    required this.sort,
    required this.onRemoveSkill,
    required this.onResetSort,
    required this.onClearAll,
  });

  final Set<String> selectedSkills;
  final AgentSort sort;
  final ValueChanged<String> onRemoveSkill;
  final VoidCallback onResetSort;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('market-active-filters'),
      spacing: Puls3Spacing.xs,
      runSpacing: Puls3Spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (sort != AgentSort.featured)
          SkillChip(
            label: sort.l10nLabel(context.l10n),
            selected: true,
            onDelete: onResetSort,
          ),
        for (final skill in selectedSkills)
          SkillChip(
            label: localizedSkillName(context.l10n, skill),
            selected: true,
            onDelete: () => onRemoveSkill(skill),
          ),
        TextButton(
          key: const Key('market-clear-all'),
          onPressed: onClearAll,
          child: Text(context.l10n.marketClearAll),
        ),
      ],
    );
  }
}
