import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../studio/studio_gateway.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/price_tag.dart';
import '../atoms/section_label.dart';
import '../atoms/skeleton_box.dart';
import '../molecules/empty_state.dart';
import '../molecules/error_banner.dart';

/// The S12 list of the builder's drafts and agents, grouped as **Drafts**,
/// **Deploying or failed** and **Live**. Purely presentational: the
/// container loads the drafts and handles the actions.
class MyAgentsList extends StatelessWidget {
  const MyAgentsList({
    super.key,
    required this.drafts,
    required this.loading,
    required this.onRetry,
    required this.onNewAgent,
    required this.onContinue,
    required this.onResume,
    required this.onView,
    required this.onEdit,
    this.error,
  });

  /// Null until the first load answers.
  final List<StudioDraft>? drafts;
  final bool loading;

  /// Why the list could not be loaded; shows the error banner.
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onNewAgent;
  final ValueChanged<StudioDraft> onContinue;
  final ValueChanged<StudioDraft> onResume;
  final ValueChanged<StudioDraft> onView;
  final ValueChanged<StudioDraft> onEdit;

  @override
  Widget build(BuildContext context) {
    final drafts = this.drafts;
    final error = this.error;
    if (error != null) {
      return ErrorBanner(
        key: const Key('my-agents-error'),
        title: context.l10n.myAgentsLoadError,
        message: error,
        onRetry: onRetry,
        retrying: loading,
      );
    }
    if (drafts == null) return const _Skeleton();
    if (drafts.isEmpty) {
      return EmptyState(
        key: const Key('my-agents-empty'),
        icon: Icons.smart_toy_outlined,
        title: context.l10n.myAgentsEmptyTitle,
        message: context.l10n.myAgentsEmptyMessage,
        actionLabel: context.l10n.myAgentsEmptyAction,
        onAction: onNewAgent,
      );
    }
    final l10n = context.l10n;
    final groups = [
      (
        l10n.myAgentsDrafts,
        [
          for (final d in drafts)
            if (d.deployState == DraftDeployState.draft) d,
        ],
      ),
      (
        l10n.myAgentsDeployingOrFailed,
        [
          for (final d in drafts)
            if (d.deployState == DraftDeployState.deploying ||
                d.deployState == DraftDeployState.failed)
              d,
        ],
      ),
      (
        l10n.myAgentsLive,
        [
          for (final d in drafts)
            if (d.deployState == DraftDeployState.live) d,
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, rows) in groups)
          if (rows.isNotEmpty) ...[
            SectionLabel(title),
            const SizedBox(height: Puls3Spacing.sm),
            for (final draft in rows) ...[
              AgentVersionRow(
                draft: draft,
                onContinue: () => onContinue(draft),
                onResume: () => onResume(draft),
                onView: draft.agentId == null ? null : () => onView(draft),
                onEdit: () => onEdit(draft),
              ),
              const SizedBox(height: Puls3Spacing.xs),
            ],
            const SizedBox(height: Puls3Spacing.lg),
          ],
      ],
    );
  }
}

/// One draft or agent: name, state, version and price, with its actions.
/// Purely presentational.
class AgentVersionRow extends StatelessWidget {
  const AgentVersionRow({
    super.key,
    required this.draft,
    required this.onContinue,
    required this.onResume,
    required this.onEdit,
    this.onView,
  });

  final StudioDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onResume;
  final VoidCallback onEdit;

  /// Null when the agent is not in the catalog (a demo deploy).
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final price = draft.manifest.price;
    final (label, color) = switch (draft.deployState) {
      DraftDeployState.draft => (
        l10n.myAgentsDraftRevision(draft.revision),
        Puls3Colors.muted,
      ),
      DraftDeployState.deploying => (l10n.myAgentsDeploying, Puls3Colors.lavender),
      DraftDeployState.failed => (l10n.myAgentsDeployFailed, Puls3Colors.accent),
      DraftDeployState.live => (
        l10n.myAgentsLiveVersion(draft.liveVersion ?? 1),
        Puls3Colors.success,
      ),
    };
    final step = draft.retryFromStep;
    final actions = switch (draft.deployState) {
      DraftDeployState.draft => [
        _action(l10n.myAgentsContinue, onContinue, 'continue'),
      ],
      DraftDeployState.deploying || DraftDeployState.failed => [
        _action(
          step == null
              ? l10n.myAgentsResume
              : l10n.myAgentsResumeStep(step),
          onResume,
          'resume',
        ),
      ],
      DraftDeployState.live => [
        if (onView != null) _action(l10n.myAgentsView, onView!, 'view'),
        _action(l10n.myAgentsEdit, onEdit, 'edit'),
      ],
    };
    return Container(
      key: Key('my-agents-row-${draft.draftId}'),
      padding: const EdgeInsets.all(Puls3Spacing.sm),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: Puls3Spacing.xs,
        spacing: Puls3Spacing.sm,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  draft.name == 'Untitled agent'
                      ? l10n.agentUntitled
                      : draft.name,
                  style: Puls3Text.title,
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: Puls3Spacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Puls3Text.caption.copyWith(color: color),
                    ),
                    if (price != null) PriceTag(stroops: price.stroops),
                  ],
                ),
              ],
            ),
          ),
          Wrap(spacing: Puls3Spacing.xs, children: actions),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback onPressed, String id) => TextButton(
    key: Key('my-agents-$id-${draft.draftId}'),
    onPressed: onPressed,
    child: Text(label),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('my-agents-loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final title in [
          context.l10n.myAgentsDrafts,
          context.l10n.myAgentsLive,
        ]) ...[
          SectionLabel(title),
          const SizedBox(height: Puls3Spacing.sm),
          for (var i = 0; i < 2; i++) ...[
            Container(
              padding: const EdgeInsets.all(Puls3Spacing.sm),
              decoration: BoxDecoration(
                color: Puls3Colors.surface,
                borderRadius: Puls3Radius.mdAll,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 180, height: 18),
                  SizedBox(height: Puls3Spacing.xs),
                  SkeletonBox(width: 120),
                ],
              ),
            ),
            const SizedBox(height: Puls3Spacing.xs),
          ],
          const SizedBox(height: Puls3Spacing.lg),
        ],
      ],
    );
  }
}
