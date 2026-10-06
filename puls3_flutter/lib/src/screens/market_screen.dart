import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent.dart';
import '../domain/agent_filter.dart';
import '../state/app_scope.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/agent_avatar.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/price_tag.dart';
import '../ui/atoms/rating_badge.dart';
import '../ui/atoms/skeleton_box.dart';
import '../ui/atoms/skill_chip.dart';
import '../ui/molecules/agent_list_card.dart';
import '../ui/molecules/screen_header.dart';
import '../ui/organisms/agent_grid.dart';
import '../ui/organisms/site_footer.dart';

/// `/market`: search, skill filters, sorting, a "Top rated" carousel and
/// the results (a compact list on phones, a grid on wider screens).
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _search = TextEditingController();
  final Set<String> _selectedSkills = {};
  AgentSort _sort = AgentSort.recommended;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSkill(String skill) => setState(() {
    if (!_selectedSkills.remove(skill)) _selectedSkills.add(skill);
  });

  void _clearAll() {
    _search.clear();
    setState(() {
      _selectedSkills.clear();
      _sort = AgentSort.recommended;
    });
  }

  Future<void> _openSort() async {
    final picked = await showModalBottomSheet<AgentSort>(
      context: context,
      useSafeArea: true,
      backgroundColor: Puls3Colors.surface,
      showDragHandle: true,
      builder: (context) => _SortSheet(current: _sort),
    );
    if (picked != null) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    return ListenableBuilder(
      listenable: Listenable.merge([catalog, _search]),
      builder: (context, _) {
        final compact = isCompactLayout(context);
        final filtering =
            _search.text.trim().isNotEmpty || _selectedSkills.isNotEmpty;
        final visible = sortAgents(
          filterAgents(
            catalog.agents,
            query: _search.text,
            skills: _selectedSkills,
          ),
          _sort,
        );
        final featured = sortAgents(
          catalog.agents,
          AgentSort.topRated,
        ).take(5).toList();
        final gap = compact ? Puls3Spacing.md : Puls3Spacing.lg;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: compact ? Puls3Spacing.md : Puls3Spacing.xl,
                    ),
                    ScreenHeader(
                      title: 'Marketplace',
                      subtitle:
                          'Find an agent, hire it, pay it in USDC on Stellar.',
                      // Doto stat accent (brand guide page 11).
                      trailing: Text(
                        compact
                            ? '${catalog.agents.length} LIVE'
                            : '${catalog.agents.length} AGENTS LIVE',
                        style: compact
                            ? Puls3Text.accentMd.copyWith(fontSize: 16)
                            : Puls3Text.accentMd,
                      ),
                    ),
                    SizedBox(height: gap),
                    _SearchRow(
                      controller: _search,
                      sortActive: _sort != AgentSort.recommended,
                      onSort: _openSort,
                    ),
                    const SizedBox(height: Puls3Spacing.sm),
                  ],
                ),
              ),
              // Skill filters scroll sideways instead of wrapping into rows.
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? Puls3Spacing.md : Puls3Spacing.xl,
                  ),
                  children: [
                    SkillChip(
                      label: 'All',
                      selected: _selectedSkills.isEmpty,
                      onTap: () => setState(_selectedSkills.clear),
                    ),
                    for (final skill in catalog.allSkills) ...[
                      const SizedBox(width: Puls3Spacing.xs),
                      SkillChip(
                        label: skill,
                        selected: _selectedSkills.contains(skill),
                        onTap: () => _toggleSkill(skill),
                      ),
                    ],
                  ],
                ),
              ),
              if (!filtering && featured.length > 1) ...[
                SizedBox(height: gap),
                ContentWidth(
                  child: _SectionTitle(
                    title: 'Top rated',
                    icon: Icons.star_rounded,
                  ),
                ),
                const SizedBox(height: Puls3Spacing.sm),
                SizedBox(
                  height: 164,
                  child: ListView.separated(
                    key: const ValueKey('featured-carousel'),
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? Puls3Spacing.md : Puls3Spacing.xl,
                    ),
                    itemCount: featured.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: Puls3Spacing.sm),
                    itemBuilder: (context, i) => _FeaturedCard(
                      agent: featured[i],
                      onTap: () => context.go('/agent/${featured[i].id}'),
                    ),
                  ),
                ),
              ],
              ContentWidth(
                child: Column(
                  key: const ValueKey('market-results'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: gap),
                    _SectionTitle(
                      title: filtering ? 'Results' : 'All agents',
                      count: visible.length,
                      trailing: _sort == AgentSort.recommended
                          ? null
                          : _sort.label,
                    ),
                    const SizedBox(height: Puls3Spacing.sm),
                    if (catalog.isLoading && catalog.agents.isEmpty)
                      const _CatalogSkeleton()
                    else if (visible.isEmpty)
                      _EmptyResults(onClear: _clearAll)
                    else if (compact)
                      for (final agent in visible)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: Puls3Spacing.xs,
                          ),
                          child: AgentListCard(
                            key: ValueKey('agent-${agent.id}'),
                            agent: agent,
                            onTap: () => context.go('/agent/${agent.id}'),
                          ),
                        )
                    else
                      AgentGrid(
                        agents: visible,
                        onSelect: (agent) => context.go('/agent/${agent.id}'),
                      ),
                    SizedBox(height: compact ? Puls3Spacing.lg : 48),
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

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.sortActive,
    required this.onSort,
  });

  final TextEditingController controller;
  final bool sortActive;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: Puls3Text.body.copyWith(fontSize: 15),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search agents...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: controller.clear,
                    ),
            ),
          ),
        ),
        const SizedBox(width: Puls3Spacing.xs),
        Badge(
          isLabelVisible: sortActive,
          smallSize: 8,
          backgroundColor: Puls3Colors.accent,
          child: IconButton.outlined(
            tooltip: 'Sort and filter',
            onPressed: onSort,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              side: const BorderSide(color: Puls3Colors.hairline),
            ),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
        ),
      ],
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.current});

  final AgentSort current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, Puls3Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Puls3Spacing.md),
            child: Text(
              'Sort by',
              style: Puls3Text.title.copyWith(fontSize: 16),
            ),
          ),
          const SizedBox(height: Puls3Spacing.xs),
          for (final sort in AgentSort.values)
            ListTile(
              title: Text(
                sort.label,
                style: Puls3Text.body.copyWith(fontSize: 14),
              ),
              trailing: sort == current
                  ? const Icon(Icons.check_rounded, color: Puls3Colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(sort),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.icon,
    this.count,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final int? count;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Puls3Colors.accent),
          const SizedBox(width: Puls3Spacing.xxs),
        ],
        Text(title, style: Puls3Text.title.copyWith(fontSize: 15)),
        if (count != null) ...[
          const SizedBox(width: Puls3Spacing.xs),
          Text(
            '$count',
            style: Puls3Text.bodyMuted.copyWith(fontSize: 13),
          ),
        ],
        const Spacer(),
        if (trailing != null)
          Flexible(
            child: Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Puls3Text.bodyMuted.copyWith(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// A card in the "Top rated" carousel.
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.agent, required this.onTap});

  final Agent agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 248,
      child: Material(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AgentAvatar(name: agent.name, size: 36),
                    const SizedBox(width: Puls3Spacing.xs),
                    Expanded(
                      child: Text(
                        agent.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Puls3Text.title.copyWith(fontSize: 14),
                      ),
                    ),
                    RatingBadge(rating: agent.rating),
                  ],
                ),
                const SizedBox(height: Puls3Spacing.xs),
                Expanded(
                  child: Text(
                    agent.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Puls3Text.bodyMuted.copyWith(
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SkillChip(label: agent.topSkill, dense: true),
                      ),
                    ),
                    PriceTag(stroops: agent.priceUsdcStroops, suffix: null),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder cards while the catalog loads, so the page is never empty.
class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('catalog-skeleton'),
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 104,
            margin: const EdgeInsets.only(bottom: Puls3Spacing.xs),
            padding: const EdgeInsets.all(Puls3Spacing.sm),
            decoration: BoxDecoration(
              color: Puls3Colors.surface,
              borderRadius: Puls3Radius.mdAll,
              border: Border.all(color: Puls3Colors.hairline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 16),
                SizedBox(height: Puls3Spacing.sm),
                SkeletonBox(width: double.infinity, height: 12),
                SizedBox(height: Puls3Spacing.xs),
                SkeletonBox(width: 180, height: 12),
              ],
            ),
          ),
      ],
    );
  }
}

/// What to show when search and filters match nothing.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xl),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 32,
              color: Puls3Colors.muted,
            ),
            const SizedBox(height: Puls3Spacing.sm),
            Text(
              'No agents found',
              style: Puls3Text.title.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              'Try another search.',
              style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
            ),
            const SizedBox(height: Puls3Spacing.sm),
            TextButton(onPressed: onClear, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}
