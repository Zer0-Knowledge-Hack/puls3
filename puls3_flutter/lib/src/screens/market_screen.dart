import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/agent_filter.dart';
import '../l10n/l10n.dart';
import '../state/agent_catalog.dart';
import '../state/app_scope.dart';
import '../theme/breakpoints.dart';
import '../theme/puls3_theme.dart';
import '../ui/atoms/content_width.dart';
import '../ui/atoms/skill_chip.dart';
import '../ui/molecules/empty_state.dart';
import '../ui/molecules/error_banner.dart';
import '../ui/organisms/agent_grid.dart';
import '../ui/organisms/market_filters.dart';
import '../ui/organisms/site_footer.dart';

/// `/market` (S02, flow F2): searchable, filterable, sortable grid of
/// agents. On phones the skills and the sort order move to a Filters sheet,
/// so the first screen shows agents instead of every skill chip.
///
/// The container: it reads the [AgentCatalog] and owns the search, skill
/// selection and sort order. Loading, error (with Retry), demo, empty and
/// no-match states are presentational widgets.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _search = TextEditingController();
  final Set<String> _selectedSkills = {};
  AgentSort _sort = AgentSort.featured;

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
    _sort = AgentSort.featured;
  });

  int get _activeFilters =>
      _selectedSkills.length + (_sort == AgentSort.featured ? 0 : 1);

  /// Phones: skills and sort order in a sheet. The selection applies on
  /// "Show N agents"; closing the sheet otherwise keeps the old one.
  Future<void> _openFilters(AgentCatalog catalog) async {
    final skills = {..._selectedSkills};
    var sort = _sort;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      // Above the bottom navigation bar, like the other sheets.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Puls3Spacing.md,
            Puls3Spacing.md,
            Puls3Spacing.md,
            Puls3Spacing.lg,
          ),
          child: MarketFilters(
            skills: catalog.allSkills,
            selectedSkills: skills,
            sort: sort,
            resultCount: filterAgents(
              catalog.agents,
              query: _search.text,
              skills: skills,
            ).length,
            onToggleSkill: (skill) => setSheet(() {
              if (!skills.remove(skill)) skills.add(skill);
            }),
            onSort: (value) => setSheet(() => sort = value),
            onReset: () => setSheet(() {
              skills.clear();
              sort = AgentSort.featured;
            }),
            onApply: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
      ),
    );
    if (applied != true || !mounted) return;
    setState(() {
      _selectedSkills
        ..clear()
        ..addAll(skills);
      _sort = sort;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = AppScope.of(context).catalog;
    return ListenableBuilder(
      listenable: Listenable.merge([catalog, _search]),
      builder: (context, _) {
        final visible = sortAgents(
          filterAgents(
            catalog.agents,
            query: _search.text,
            skills: _selectedSkills,
          ),
          _sort,
        );
        final compact = isCompactLayout(context);
        return SingleChildScrollView(
          child: Column(
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: compact ? Puls3Spacing.md : Puls3Spacing.xl,
                    ),
                    _header(catalog, compact),
                    SizedBox(
                      height: compact ? Puls3Spacing.sm : Puls3Spacing.lg,
                    ),
                    Row(
                      children: [
                        Expanded(child: _searchField()),
                        if (compact) ...[
                          const SizedBox(width: Puls3Spacing.xs),
                          _FiltersButton(
                            active: _activeFilters,
                            onPressed: () => _openFilters(catalog),
                          ),
                        ],
                      ],
                    ),
                    if (compact && _activeFilters > 0) ...[
                      const SizedBox(height: Puls3Spacing.sm),
                      ActiveFilters(
                        selectedSkills: _selectedSkills,
                        sort: _sort,
                        onRemoveSkill: _toggleSkill,
                        onResetSort: () =>
                            setState(() => _sort = AgentSort.featured),
                        onClearAll: _clearFilters,
                      ),
                    ],
                    if (!compact) ...[
                      const SizedBox(height: Puls3Spacing.md),
                      _skillChips(catalog),
                    ],
                    SizedBox(
                      height: compact ? Puls3Spacing.md : Puls3Spacing.lg,
                    ),
                    ..._results(catalog, visible.length, compact),
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

  /// Title with the live count, the tagline and Create agent. Phones get a
  /// compact title, as in an app header.
  Widget _header(AgentCatalog catalog, bool compact) {
    final width = MediaQuery.sizeOf(context).width;
    final title = compact
        ? Puls3Text.h3.copyWith(fontSize: 22, fontWeight: FontWeight.w600)
        : width < Puls3Breakpoints.compactHeadline
        ? Puls3Text.h2Compact
        : Puls3Text.h1;
    final stat = compact
        ? Puls3Text.accentMd.copyWith(fontSize: 14)
        : Puls3Text.accentMd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: Puls3Spacing.lg,
          runSpacing: Puls3Spacing.xs,
          children: [
            Text(context.l10n.marketTitle, style: title),
            // Doto stat accent (brand guide page 11).
            if (catalog.status == CatalogStatus.ready)
              Text(
                context.l10n.marketAgentsLive(catalog.agents.length),
                style: stat,
              )
            else if (catalog.status == CatalogStatus.demo)
              Text(context.l10n.marketDemoCatalog, style: stat),
          ],
        ),
        const SizedBox(height: Puls3Spacing.xxs),
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.marketLead,
                style: compact
                    ? Puls3Text.bodyMuted.copyWith(fontSize: 14)
                    : Puls3Text.lead,
              ),
            ),
            const SizedBox(width: Puls3Spacing.xs),
            TextButton.icon(
              key: const Key('market-create-agent'),
              onPressed: () => context.go('/studio'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.l10n.marketCreateAgent),
            ),
          ],
        ),
      ],
    );
  }

  Widget _searchField() => TextField(
    key: const Key('market-search'),
    controller: _search,
    style: Puls3Text.body,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: context.l10n.marketSearchHint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: context.l10n.marketClearSearch,
              icon: const Icon(Icons.close_rounded),
              onPressed: _search.clear,
            ),
    ),
  );

  /// Wider screens: every skill as a chip, as in the S02 wireframe.
  Widget _skillChips(AgentCatalog catalog) => Wrap(
    spacing: Puls3Spacing.xs,
    runSpacing: Puls3Spacing.xs,
    children: [
      SkillChip(
        label: context.l10n.commonAll,
        selected: _selectedSkills.isEmpty,
        onTap: () => setState(_selectedSkills.clear),
      ),
      for (final skill in catalog.allSkills)
        SkillChip(
          label: localizedSkillName(context.l10n, skill),
          selected: _selectedSkills.contains(skill),
          onTap: () => _toggleSkill(skill),
        ),
    ],
  );

  /// The banner, count and empty states above the grid, by catalog state.
  List<Widget> _results(AgentCatalog catalog, int visible, bool compact) {
    final retry = catalog.retry;
    return switch (catalog.status) {
      CatalogStatus.loading => const [
        AgentGridSkeleton(key: ValueKey('market-loading')),
      ],
      CatalogStatus.error => [
        ErrorBanner(
          key: const ValueKey('market-error'),
          title: context.l10n.marketCouldNotLoad,
          message: context.l10n.marketCouldNotLoadMessage,
          retrying: catalog.isLoading,
          onRetry: retry,
        ),
      ],
      CatalogStatus.demo || CatalogStatus.ready => [
        if (catalog.status == CatalogStatus.demo) ...[
          ErrorBanner(
            key: const ValueKey('market-demo'),
            title: context.l10n.marketDemoTitle,
            message: context.l10n.marketDemoMessage,
            retrying: catalog.isLoading,
            onRetry: retry,
          ),
          const SizedBox(height: Puls3Spacing.md),
        ],
        if (catalog.agents.isEmpty)
          EmptyState(
            key: const ValueKey('market-empty'),
            icon: Icons.hub_outlined,
            title: context.l10n.marketEmptyTitle,
            message: context.l10n.marketEmptyMessage,
            actionLabel: context.l10n.marketEmptyAction,
            onAction: () => context.go('/studio'),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.marketShowingCount(
                    visible,
                    catalog.agents.length,
                  ),
                  style: Puls3Text.eyebrow,
                ),
              ),
              if (!compact)
                _SortMenu(
                  sort: _sort,
                  onSort: (value) => setState(() => _sort = value),
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.sm),
          if (visible == 0)
            EmptyState(
              key: const ValueKey('market-no-match'),
              icon: Icons.search_off_rounded,
              title: context.l10n.marketNoMatchTitle,
              message: context.l10n.marketNoMatchMessage,
              actionLabel: context.l10n.marketClearFilters,
              onAction: _clearFilters,
            ),
        ],
      ],
    };
  }
}

/// Phones: opens the filters sheet, with the number of active filters.
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.active, required this.onPressed});

  final int active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: active > 0,
      label: Text('$active'),
      backgroundColor: Puls3Colors.accent,
      textColor: Puls3Colors.onAccent,
      child: IconButton.outlined(
        key: const Key('market-filters-button'),
        tooltip: active == 0
            ? context.l10n.marketFilters
            : context.l10n.marketFiltersActive(active),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Puls3Colors.hairline),
          shape: RoundedRectangleBorder(borderRadius: Puls3Radius.mdAll),
        ),
        icon: const Icon(Icons.tune_rounded),
      ),
    );
  }
}

/// Wider screens: the sort order beside the result count.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSort});

  final AgentSort sort;
  final ValueChanged<AgentSort> onSort;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AgentSort>(
      key: const Key('market-sort-menu'),
      tooltip: context.l10n.marketSortAgents,
      initialValue: sort,
      onSelected: onSort,
      itemBuilder: (context) => [
        for (final option in AgentSort.values)
          PopupMenuItem(
            value: option,
            child: Text(option.l10nLabel(context.l10n)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: Puls3Colors.muted),
            const SizedBox(width: Puls3Spacing.xxs),
            Text(sort.l10nLabel(context.l10n), style: Puls3Text.caption),
          ],
        ),
      ),
    );
  }
}
