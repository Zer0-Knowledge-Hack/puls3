import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent_filter.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/skill_chip.dart';
import '../ui/organisms/agent_grid.dart';
import '../ui/organisms/site_footer.dart';

/// `/market`: searchable, filterable grid of agents.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _search = TextEditingController();
  final Set<String> _selectedSkills = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSkill(String skill) => setState(() {
    if (!_selectedSkills.remove(skill)) _selectedSkills.add(skill);
  });

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    return ListenableBuilder(
      listenable: Listenable.merge([catalog, _search]),
      builder: (context, _) {
        final visible = filterAgents(
          catalog.agents,
          query: _search.text,
          skills: _selectedSkills,
        );
        return SingleChildScrollView(
          child: Column(
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Puls3Spacing.xl),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: Puls3Spacing.lg,
                      runSpacing: Puls3Spacing.xs,
                      children: [
                        Text(
                          'Marketplace',
                          style: MediaQuery.sizeOf(context).width < 700
                              ? Puls3Text.h2Compact
                              : Puls3Text.h1,
                        ),
                        // Doto stat accent (brand guide page 11).
                        Text(
                          '${catalog.agents.length} AGENTS LIVE',
                          style: Puls3Text.accentMd,
                        ),
                      ],
                    ),
                    const SizedBox(height: Puls3Spacing.xs),
                    Text(
                      'Find an agent, hire it, pay it in USDC on Stellar.',
                      style: Puls3Text.lead,
                    ),
                    const SizedBox(height: Puls3Spacing.lg),
                    TextField(
                      controller: _search,
                      style: Puls3Text.body,
                      decoration: const InputDecoration(
                        hintText: 'Search agents, skills or models',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: Puls3Spacing.md),
                    Wrap(
                      spacing: Puls3Spacing.xs,
                      runSpacing: Puls3Spacing.xs,
                      children: [
                        SkillChip(
                          label: 'All',
                          selected: _selectedSkills.isEmpty,
                          onTap: () => setState(_selectedSkills.clear),
                        ),
                        for (final skill in catalog.allSkills)
                          SkillChip(
                            label: skill,
                            selected: _selectedSkills.contains(skill),
                            onTap: () => _toggleSkill(skill),
                          ),
                      ],
                    ),
                    const SizedBox(height: Puls3Spacing.lg),
                    Text(
                      'SHOWING ${visible.length} OF ${catalog.agents.length}',
                      style: Puls3Text.eyebrow,
                    ),
                    const SizedBox(height: Puls3Spacing.sm),
                    if (catalog.isLoading && catalog.agents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(Puls3Spacing.xxl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Puls3Spacing.xxl,
                        ),
                        child: Center(
                          child: Text(
                            'No agents match your filters.',
                            style: Puls3Text.bodyMuted,
                          ),
                        ),
                      )
                    else
                      AgentGrid(
                        agents: visible,
                        onSelect: (agent) => context.go('/agent/${agent.id}'),
                      ),
                    const SizedBox(height: Puls3Spacing.xxl),
                  ],
                ),
              ),
              const SiteFooter(),
            ],
          ),
        );
      },
    );
  }
}
