import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent_filter.dart';
import '../state/agent_catalog.dart';
import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/skill_chip.dart';
import '../ui/molecules/empty_state.dart';
import '../ui/molecules/error_banner.dart';
import '../ui/organisms/agent_grid.dart';
import '../ui/organisms/site_footer.dart';

/// `/market` (S02, flow F2): searchable, filterable grid of agents.
///
/// The container: it reads the [AgentCatalog] and owns the search and skill
/// selection. Loading, error (with Retry), demo, empty and no-match states
/// are presentational widgets.
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

  void _clearFilters() => setState(() {
    _search.clear();
    _selectedSkills.clear();
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
                          style:
                              MediaQuery.sizeOf(context).width <
                                  Puls3Breakpoints.compactHeadline
                              ? Puls3Text.h2Compact
                              : Puls3Text.h1,
                        ),
                        // Doto stat accent (brand guide page 11).
                        if (catalog.status == CatalogStatus.ready)
                          Text(
                            '${catalog.agents.length} AGENTS LIVE',
                            style: Puls3Text.accentMd,
                          )
                        else if (catalog.status == CatalogStatus.demo)
                          Text('DEMO CATALOG', style: Puls3Text.accentMd),
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
                      decoration: InputDecoration(
                        hintText: 'Search agents, skills or models',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _search.clear,
                              ),
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
                    ..._results(catalog, visible.length),
                    if (visible.isNotEmpty)
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

  /// The banner, count and empty states above the grid, by catalog state.
  List<Widget> _results(AgentCatalog catalog, int visible) {
    final retry = catalog.retry;
    return switch (catalog.status) {
      CatalogStatus.loading => const [
        AgentGridSkeleton(key: ValueKey('market-loading')),
      ],
      CatalogStatus.error => [
        ErrorBanner(
          key: const ValueKey('market-error'),
          title: 'Could not load the agents',
          message:
              'The puls3 server did not answer. Check your connection '
              'and try again.',
          retrying: catalog.isLoading,
          onRetry: retry,
        ),
      ],
      CatalogStatus.demo || CatalogStatus.ready => [
        if (catalog.status == CatalogStatus.demo) ...[
          ErrorBanner(
            key: const ValueKey('market-demo'),
            title: 'Showing the demo catalog',
            message:
                'The puls3 server is unreachable, so these agents are '
                'not read from the chain.',
            retrying: catalog.isLoading,
            onRetry: retry,
          ),
          const SizedBox(height: Puls3Spacing.md),
        ],
        if (catalog.agents.isEmpty)
          EmptyState(
            key: const ValueKey('market-empty'),
            icon: Icons.hub_outlined,
            title: 'No agents yet',
            message:
                'Agents registered on-chain appear here. Be the first '
                'to publish one.',
            actionLabel: 'Create an agent',
            onAction: () => context.go('/studio'),
          )
        else ...[
          Text(
            'SHOWING $visible OF ${catalog.agents.length}',
            style: Puls3Text.eyebrow,
          ),
          const SizedBox(height: Puls3Spacing.sm),
          if (visible == 0)
            EmptyState(
              key: const ValueKey('market-no-match'),
              icon: Icons.search_off_rounded,
              title: 'No matching agents',
              message: 'Try another search or fewer skills.',
              actionLabel: 'Clear filters',
              onAction: _clearFilters,
            ),
        ],
      ],
    };
  }
}
