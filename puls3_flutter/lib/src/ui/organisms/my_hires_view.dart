import 'package:flutter/material.dart';

import '../../hire/hire_gateway.dart';
import '../../l10n/l10n.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/price_tag.dart';
import '../molecules/empty_state.dart';

/// My hires: the wallet's hires split into three tabs (needs your action,
/// in progress, finished). Purely presentational; the screen loads [hires]
/// and handles [onOpenHire] and [onBrowseMarketplace].
class MyHiresView extends StatelessWidget {
  const MyHiresView({
    super.key,
    required this.hires,
    required this.onOpenHire,
    required this.onBrowseMarketplace,
    this.isDemo = false,
    this.initialTab = HireListTab.needsAction,
  });

  final List<HireSummaryItem> hires;
  final ValueChanged<int> onOpenHire;
  final VoidCallback onBrowseMarketplace;
  final bool isDemo;
  final HireListTab initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    List<HireSummaryItem> of(HireListTab tab) => [
      for (final hire in hires)
        if (hire.tab == tab) hire,
    ];
    final labels = {
      HireListTab.needsAction: l10n.myHiresTabNeedsAction,
      HireListTab.inProgress: l10n.myHiresTabInProgress,
      HireListTab.finished: l10n.myHiresTabFinished,
    };
    return DefaultTabController(
      length: HireListTab.values.length,
      initialIndex: initialTab.index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDemo)
            Padding(
              padding: const EdgeInsets.only(bottom: Puls3Spacing.sm),
              child: Text(l10n.myHiresDemoNote, style: Puls3Text.caption),
            ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Puls3Colors.text,
            unselectedLabelColor: Puls3Colors.muted,
            indicatorColor: Puls3Colors.accent,
            tabs: [
              for (final tab in HireListTab.values)
                Tab(
                  key: ValueKey('my-hires-tab-${tab.name}'),
                  text: '${labels[tab]} (${of(tab).length})',
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.md),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in HireListTab.values)
                  _HireList(
                    key: ValueKey('my-hires-list-${tab.name}'),
                    tab: tab,
                    hires: of(tab),
                    onOpenHire: onOpenHire,
                    onBrowseMarketplace: onBrowseMarketplace,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HireList extends StatelessWidget {
  const _HireList({
    super.key,
    required this.tab,
    required this.hires,
    required this.onOpenHire,
    required this.onBrowseMarketplace,
  });

  final HireListTab tab;
  final List<HireSummaryItem> hires;
  final ValueChanged<int> onOpenHire;
  final VoidCallback onBrowseMarketplace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (hires.isEmpty) {
      final (title, body) = switch (tab) {
        HireListTab.needsAction => (
          l10n.myHiresEmptyNeedsActionTitle,
          l10n.myHiresEmptyNeedsActionBody,
        ),
        HireListTab.inProgress => (
          l10n.myHiresEmptyInProgressTitle,
          l10n.myHiresEmptyInProgressBody,
        ),
        HireListTab.finished => (
          l10n.myHiresEmptyFinishedTitle,
          l10n.myHiresEmptyFinishedBody,
        ),
      };
      return SingleChildScrollView(
        child: EmptyState(
          key: ValueKey('my-hires-empty-${tab.name}'),
          icon: Icons.receipt_long_outlined,
          title: title,
          message: body,
          actionLabel: l10n.myHiresBrowseMarketplace,
          onAction: onBrowseMarketplace,
        ),
      );
    }
    return ListView.separated(
      itemCount: hires.length,
      separatorBuilder: (_, _) => const SizedBox(height: Puls3Spacing.sm),
      itemBuilder: (context, i) =>
          _HireRow(hire: hires[i], onTap: () => onOpenHire(hires[i].hireId)),
    );
  }
}

class _HireRow extends StatelessWidget {
  const _HireRow({required this.hire, required this.onTap});

  final HireSummaryItem hire;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deadline = hire.approvalDeadline;
    final showDeadline = deadline != null && hire.status == 'submitted';
    return Material(
      color: Puls3Colors.surface,
      borderRadius: BorderRadius.circular(Puls3Radius.md),
      child: InkWell(
        key: ValueKey('my-hires-row-${hire.hireId}'),
        borderRadius: BorderRadius.circular(Puls3Radius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Puls3Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hire.agentName,
                      style: Puls3Text.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Puls3Spacing.sm),
                  _StatusChip(hire: hire),
                ],
              ),
              const SizedBox(height: Puls3Spacing.xxs),
              Text(
                hire.inputPreview,
                style: Puls3Text.bodyMuted,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Puls3Spacing.xs),
              Wrap(
                spacing: Puls3Spacing.md,
                runSpacing: Puls3Spacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PriceTag(stroops: hire.priceUsdcStroops, perTask: false),
                  if (showDeadline)
                    Text(
                      l10n.myHiresApproveBy(
                        MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(deadline.toLocal()),
                      ),
                      style: Puls3Text.caption.copyWith(
                        color: Puls3Colors.accent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.hire});

  final HireSummaryItem hire;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (hire.status) {
      'funded' => l10n.myHiresStatusInProgress,
      'submitted' => l10n.myHiresStatusReview,
      'completed' => l10n.myHiresStatusCompleted,
      'rejected' => l10n.myHiresStatusRejected,
      'expired' => l10n.myHiresStatusExpired,
      _ => l10n.myHiresStatusAwaitingPayment,
    };
    final color = switch (hire.tab) {
      HireListTab.needsAction => Puls3Colors.accent,
      HireListTab.inProgress => Puls3Colors.lavender,
      HireListTab.finished => Puls3Colors.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Puls3Spacing.xs,
        vertical: Puls3Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Puls3Radius.pill),
      ),
      child: Text(label, style: Puls3Text.caption.copyWith(color: color)),
    );
  }
}
