import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Signal colors for rule examples. tokens.json has no error color, so the
/// "don't" red is defined here for the brand page only.
abstract final class RuleColors {
  static const Color good = Puls3Colors.success;
  static const Color bad = Color(0xFFF2555A);
}

/// A rendered example of a brand rule: a ✓ or ✗ badge with an optional
/// [title], the example centered on [background] (and [backdrop]), a green
/// or red bottom border, and an optional [caption] below the card.
class RuleExampleCard extends StatelessWidget {
  const RuleExampleCard({
    super.key,
    required this.good,
    required this.example,
    this.title,
    this.caption,
    this.background = Puls3Colors.surface,
    this.backdrop,
    this.height = 200,
  });

  final bool good;
  final Widget example;
  final String? title;
  final String? caption;
  final Color background;

  /// Painted full-bleed behind the example, e.g. a busy pattern.
  final Widget? backdrop;
  final double height;

  @override
  Widget build(BuildContext context) {
    final signal = good ? RuleColors.good : RuleColors.bad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: Puls3Radius.mdAll,
            border: Border(bottom: BorderSide(color: signal, width: 3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (backdrop != null) Positioned.fill(child: backdrop!),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Puls3Spacing.md,
                    Puls3Spacing.xxl,
                    Puls3Spacing.md,
                    Puls3Spacing.md,
                  ),
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: example),
                  ),
                ),
              ),
              Positioned(
                left: Puls3Spacing.sm,
                top: Puls3Spacing.sm,
                right: Puls3Spacing.sm,
                child: Row(
                  children: [
                    Semantics(
                      label: good ? 'Do' : "Don't",
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: signal,
                        child: Icon(
                          good ? Icons.check_rounded : Icons.close_rounded,
                          size: 16,
                          color: Puls3Colors.background,
                        ),
                      ),
                    ),
                    if (title != null) ...[
                      const SizedBox(width: Puls3Spacing.xs),
                      Expanded(
                        child: Text(
                          title!,
                          style: Puls3Text.title.copyWith(
                            color: background.computeLuminance() > 0.4
                                ? Puls3Colors.background
                                : Puls3Colors.text,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: Puls3Spacing.sm),
          Text(caption!, style: Puls3Text.bodyMuted),
        ],
      ],
    );
  }
}
