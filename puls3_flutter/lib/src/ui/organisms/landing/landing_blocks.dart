import 'package:flutter/material.dart';

import '../../../domain/landing_content.dart';
import '../../../theme/puls3_theme.dart';
import '../../atoms/agent_avatar.dart';

/// Landing blocks: problem, audiences, comparison, testimonials, team, FAQ
/// and trust badges. Purely presentational.

/// [count] columns by width: 3 / 2 / 1.
int _columns(double width, {int max = 3}) => width >= 900
    ? max
    : width >= 600
    ? (max >= 2 ? 2 : 1)
    : 1;

/// Lays [children] out in equal-width columns.
class LandingGrid extends StatelessWidget {
  const LandingGrid({super.key, required this.children, this.maxColumns = 3});

  final List<Widget> children;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columns(constraints.maxWidth, max: maxColumns);
        const gap = Puls3Spacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

BoxDecoration _card() => BoxDecoration(
  color: Puls3Colors.surface,
  borderRadius: Puls3Radius.mdAll,
  border: Border.all(color: Puls3Colors.hairline),
);

/// Small facts under the hero: network, asset, escrow, open source.
class TrustBadges extends StatelessWidget {
  const TrustBadges({super.key});

  static const _items = [
    (Icons.hub_outlined, 'Stellar Testnet'),
    (Icons.attach_money_rounded, 'USDC per task'),
    (Icons.shield_outlined, 'Soroban escrow'),
    (Icons.fingerprint_rounded, 'On-chain identity'),
    (Icons.code_rounded, 'Open source'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Puls3Spacing.md,
      runSpacing: Puls3Spacing.xs,
      children: [
        for (final (icon, label) in _items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: Puls3Colors.muted),
              const SizedBox(width: 4),
              Text(
                label,
                style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
              ),
            ],
          ),
      ],
    );
  }
}

/// The problem and how puls3 answers it, one card per pain point.
class ProblemCards extends StatelessWidget {
  const ProblemCards({super.key, required this.problems});

  final List<LandingProblem> problems;

  @override
  Widget build(BuildContext context) {
    return LandingGrid(
      children: [
        for (var i = 0; i < problems.length; i++)
          Container(
            padding: const EdgeInsets.all(Puls3Spacing.md),
            decoration: _card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '0${i + 1}',
                  style: Puls3Text.accentMd.copyWith(fontSize: 16),
                ),
                const SizedBox(height: Puls3Spacing.xs),
                Text(problems[i].title, style: Puls3Text.title),
                const SizedBox(height: Puls3Spacing.xxs),
                Text(
                  problems[i].body,
                  style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
                ),
                const SizedBox(height: Puls3Spacing.sm),
                const Divider(height: 1, color: Puls3Colors.hairline),
                const SizedBox(height: Puls3Spacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: Puls3Colors.success,
                      ),
                    ),
                    const SizedBox(width: Puls3Spacing.xs),
                    Expanded(
                      child: Text(
                        problems[i].answer,
                        style: Puls3Text.body.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Builders and hirers, side by side, with what each gets.
class AudienceCards extends StatelessWidget {
  const AudienceCards({
    super.key,
    required this.audiences,
    required this.actions,
  });

  final List<LandingAudience> audiences;

  /// One call to action per audience: (label, onTap).
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    return LandingGrid(
      maxColumns: 2,
      children: [
        for (var i = 0; i < audiences.length; i++)
          Container(
            padding: const EdgeInsets.all(Puls3Spacing.md),
            decoration: _card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(audiences[i].title, style: Puls3Text.title),
                const SizedBox(height: Puls3Spacing.xxs),
                Text(
                  audiences[i].lead,
                  style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
                ),
                const SizedBox(height: Puls3Spacing.sm),
                for (final point in audiences[i].points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Puls3Spacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.arrow_right_rounded,
                            size: 16,
                            color: Puls3Colors.accent,
                          ),
                        ),
                        const SizedBox(width: Puls3Spacing.xxs),
                        Expanded(
                          child: Text(
                            point,
                            style: Puls3Text.body.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (i < actions.length) ...[
                  const SizedBox(height: Puls3Spacing.xs),
                  TextButton.icon(
                    onPressed: actions[i].$2,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(actions[i].$1),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// "A listing" vs "puls3", row by row. Phones stack each row.
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({super.key, required this.rows});

  final List<LandingComparison> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 640;
        final header = Puls3Text.caption.copyWith(color: Puls3Colors.muted);
        return Container(
          decoration: _card(),
          child: Column(
            children: [
              if (!stacked)
                Padding(
                  padding: const EdgeInsets.all(Puls3Spacing.md),
                  child: Row(
                    children: [
                      Expanded(child: Text('', style: header)),
                      Expanded(
                        flex: 2,
                        child: Text('A typical agent listing', style: header),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'puls3',
                          style: header.copyWith(color: Puls3Colors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0 || !stacked)
                  const Divider(height: 1, color: Puls3Colors.hairline),
                Padding(
                  padding: const EdgeInsets.all(Puls3Spacing.md),
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rows[i].feature, style: Puls3Text.title),
                            const SizedBox(height: Puls3Spacing.xxs),
                            _cell(rows[i].listing, false),
                            const SizedBox(height: 2),
                            _cell(rows[i].puls3, true),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                rows[i].feature,
                                style: Puls3Text.body.copyWith(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _cell(rows[i].listing, false),
                            ),
                            Expanded(
                              flex: 2,
                              child: _cell(rows[i].puls3, true),
                            ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _cell(String text, bool ours) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          ours ? Icons.check_rounded : Icons.remove_rounded,
          size: 15,
          color: ours ? Puls3Colors.success : Puls3Colors.muted,
        ),
      ),
      const SizedBox(width: Puls3Spacing.xxs),
      Expanded(
        child: Text(
          text,
          style: (ours ? Puls3Text.body : Puls3Text.bodyMuted).copyWith(
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

/// Real testimonials in cards; while there are none, an honest invitation
/// to be among the first reviewers instead of invented quotes.
class TestimonialsBlock extends StatelessWidget {
  const TestimonialsBlock({
    super.key,
    required this.testimonials,
    required this.onTryIt,
    required this.onShareFeedback,
  });

  final List<Testimonial> testimonials;
  final VoidCallback onTryIt;
  final VoidCallback onShareFeedback;

  @override
  Widget build(BuildContext context) {
    if (testimonials.isNotEmpty) {
      return LandingGrid(
        children: [
          for (final t in testimonials)
            Container(
              padding: const EdgeInsets.all(Puls3Spacing.md),
              decoration: _card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    color: Puls3Colors.accent,
                  ),
                  const SizedBox(height: Puls3Spacing.xs),
                  Text(t.quote, style: Puls3Text.body.copyWith(fontSize: 15)),
                  const SizedBox(height: Puls3Spacing.md),
                  Row(
                    children: [
                      AgentAvatar(name: t.name),
                      const SizedBox(width: Puls3Spacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: Puls3Text.title),
                            Text(
                              t.role,
                              style: Puls3Text.caption.copyWith(
                                color: Puls3Colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return Container(
      key: const Key('landing-reviews-open'),
      width: double.infinity,
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                const Icon(
                  Icons.star_outline_rounded,
                  size: 20,
                  color: Puls3Colors.accent,
                ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.sm),
          Text('Reviews open with the first hires.', style: Puls3Text.title),
          const SizedBox(height: Puls3Spacing.xxs),
          Text(
            'We publish only real reviews from people who used puls3, with '
            'their permission. Each agent rating will come from paid hires, '
            'one review per hire, so it cannot be inflated. Try it on '
            'testnet and tell us what you think.',
            style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
          ),
          const SizedBox(height: Puls3Spacing.md),
          Wrap(
            spacing: Puls3Spacing.sm,
            runSpacing: Puls3Spacing.xs,
            children: [
              FilledButton(
                onPressed: onTryIt,
                style: FilledButton.styleFrom(
                  backgroundColor: Puls3Colors.accent,
                  foregroundColor: Puls3Colors.onAccent,
                ),
                child: const Text('Hire an agent on testnet'),
              ),
              OutlinedButton.icon(
                key: const Key('landing-share-feedback'),
                onPressed: onShareFeedback,
                icon: const Icon(Icons.north_east_rounded, size: 16),
                label: const Text('Share feedback'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Puls3Colors.text,
                  side: const BorderSide(color: Puls3Colors.hairline),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The team, from the repository's contributors.
class TeamGrid extends StatelessWidget {
  const TeamGrid({super.key, required this.members, required this.onOpen});

  final List<TeamMember> members;
  final ValueChanged<TeamMember> onOpen;

  @override
  Widget build(BuildContext context) {
    return LandingGrid(
      children: [
        for (final member in members)
          Material(
            color: Puls3Colors.transparent,
            child: InkWell(
              borderRadius: Puls3Radius.mdAll,
              onTap: () => onOpen(member),
              child: Container(
                padding: const EdgeInsets.all(Puls3Spacing.md),
                decoration: _card(),
                child: Row(
                  children: [
                    AgentAvatar(name: member.handle),
                    const SizedBox(width: Puls3Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${member.handle}',
                            style: Puls3Text.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.focus,
                            style: Puls3Text.caption.copyWith(
                              color: Puls3Colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.north_east_rounded,
                      size: 16,
                      color: Puls3Colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Questions that open to their answer.
class FaqList extends StatelessWidget {
  const FaqList({super.key, required this.faqs});

  final List<LandingFaq> faqs;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated box), so the tiles' ink shows.
    return Material(
      color: Puls3Colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Puls3Radius.mdAll,
        side: const BorderSide(color: Puls3Colors.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < faqs.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Puls3Colors.hairline),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: Key('faq-$i'),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: Puls3Spacing.md,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  Puls3Spacing.md,
                  0,
                  Puls3Spacing.md,
                  Puls3Spacing.md,
                ),
                iconColor: Puls3Colors.accent,
                collapsedIconColor: Puls3Colors.muted,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(
                  faqs[i].question,
                  style: Puls3Text.body.copyWith(fontWeight: FontWeight.w600),
                ),
                children: [
                  Text(
                    faqs[i].answer,
                    style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
