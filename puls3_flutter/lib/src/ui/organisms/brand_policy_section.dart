import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../brand/brand_policy.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/outlined_numeral.dart';
import '../molecules/brand_section.dart';
import '../molecules/rule_example_card.dart';

/// "Using puls3 in your project": what third-party projects can do, what to
/// avoid, and what is expected of them. Copy lives in [BrandPolicy].
class BrandPolicySection extends StatelessWidget {
  const BrandPolicySection({
    super.key,
    this.contactEmail = BrandPolicy.contactEmail,
  });

  /// The approval contact; no email link is shown while it is null.
  final String? contactEmail;

  @override
  Widget build(BuildContext context) {
    final email = contactEmail;
    return BrandSection(
      title: BrandPolicy.title,
      intro: BrandPolicy.intro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandGrid(
            minTileWidth: 340,
            maxColumns: 2,
            children: [
              _RuleList(
                title: 'What you can do',
                good: true,
                rules: BrandPolicy.canDo,
              ),
              _RuleList(
                title: 'What to avoid',
                good: false,
                rules: BrandPolicy.avoid,
              ),
            ],
          ),
          const SizedBox(height: Puls3Spacing.xxl),
          Text('Expectations', style: Puls3Text.h3),
          const SizedBox(height: Puls3Spacing.lg),
          BrandGrid(
            children: [
              for (final (i, e) in BrandPolicy.expectations.indexed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedNumeral(i + 1, size: 44),
                    const SizedBox(height: Puls3Spacing.sm),
                    Text(e.title, style: Puls3Text.title),
                    const SizedBox(height: Puls3Spacing.xs),
                    Text(e.body, style: Puls3Text.bodyMuted),
                  ],
                ),
            ],
          ),
          if (email != null) ...[
            const SizedBox(height: Puls3Spacing.lg),
            TextButton.icon(
              key: const ValueKey('policy-contact-email'),
              onPressed: () => launchUrl(Uri(scheme: 'mailto', path: email)),
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: Text(email),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({
    required this.title,
    required this.good,
    required this.rules,
  });

  final String title;
  final bool good;
  final List<String> rules;

  @override
  Widget build(BuildContext context) {
    final signal = good ? RuleColors.good : RuleColors.bad;
    return Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border(bottom: BorderSide(color: signal, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Puls3Text.title),
          const SizedBox(height: Puls3Spacing.md),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: Puls3Spacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    good ? Icons.check_rounded : Icons.close_rounded,
                    size: 18,
                    color: signal,
                  ),
                  const SizedBox(width: Puls3Spacing.sm),
                  Expanded(child: Text(rule, style: Puls3Text.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
