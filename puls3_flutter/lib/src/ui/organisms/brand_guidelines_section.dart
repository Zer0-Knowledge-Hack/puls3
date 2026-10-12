import 'package:flutter/material.dart';

import '../../brand/brand_geometry.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/brand_logo_samples.dart';
import '../atoms/dashed_line.dart';
import '../atoms/outlined_numeral.dart';
import '../atoms/ruler.dart';
import '../molecules/brand_section.dart';
import '../molecules/rule_example_card.dart';

/// "Guidelines": the numbered minimum-size rules, each with a measured
/// example and a too-small one, and the 4c safe-space diagram.
class BrandGuidelinesSection extends StatelessWidget {
  const BrandGuidelinesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const g = BrandGeometry.minLockupMarkPx;
    const h = BrandGeometry.halftoneMinMarkPx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Guidelines',
          textAlign: TextAlign.center,
          style: Puls3Text.h2,
        ),
        const SizedBox(height: Puls3Spacing.xxl),
        BrandSection(
          title: 'Dimensions',
          child: Column(
            children: [
              _DimensionRow(
                number: 1,
                title: 'Lockup',
                body:
                    'Keep the mark in the lockup at least 24 px tall on '
                    'screen. In print, keep the lockup at least 25 mm wide.',
                good: RuleExampleCard(
                  good: true,
                  title: 'Minimum size',
                  example: MeasuredSample(
                    px: g,
                    rulerTop: BrandGeometry.markTop(g),
                    child: const LockupSample(markHeight: g),
                  ),
                ),
                bad: const RuleExampleCard(
                  good: false,
                  title: '< 24 px',
                  example: LockupSample(markHeight: 16),
                ),
              ),
              const _DimensionRow(
                number: 2,
                title: 'Mark',
                body:
                    'Use the mark alone at 16 px or larger (6 mm in print). '
                    'Below 48 px, use C01-small at its 32, 24 or 16 px level.',
                good: RuleExampleCard(
                  good: true,
                  title: 'Minimum size',
                  example: MeasuredSample(
                    px: BrandGeometry.minMarkPx,
                    child: MarkSample(size: BrandGeometry.minMarkPx),
                  ),
                ),
                bad: RuleExampleCard(
                  good: false,
                  title: '< 16 px',
                  example: MarkSample(size: 10),
                ),
              ),
              const _DimensionRow(
                number: 3,
                title: 'Wordmark',
                body:
                    'Set the wordmark alone at least 14 px tall, ascender to '
                    'descender (18 mm in print). Never retype it.',
                good: RuleExampleCard(
                  good: true,
                  title: 'Minimum size',
                  example: MeasuredSample(
                    px: BrandGeometry.minWordmarkPx,
                    child: WordmarkSample(height: BrandGeometry.minWordmarkPx),
                  ),
                ),
                bad: RuleExampleCard(
                  good: false,
                  title: '< 14 px',
                  example: WordmarkSample(height: 9),
                ),
              ),
              _DimensionRow(
                number: 4,
                title: 'Halftone 3',
                body:
                    'Use the halftone 3 only when the rendered 3 is at least '
                    '40 px tall: a lockup mark of 72 px or more. Below that, '
                    'use the small lockup with the solid 3.',
                good: RuleExampleCard(
                  good: true,
                  title: 'Halftone at 72 px',
                  example: MeasuredSample(
                    px: h,
                    rulerTop: BrandGeometry.markTop(h),
                    child: const LockupSample(markHeight: h, halftone: true),
                  ),
                ),
                bad: const RuleExampleCard(
                  good: false,
                  title: 'Halftone below 72 px',
                  example: LockupSample(markHeight: 32, halftone: true),
                ),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.xxxl),
        const BrandSection(title: 'Safe space', child: _SafeSpace()),
      ],
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.number,
    required this.title,
    required this.body,
    required this.good,
    required this.bad,
    this.last = false,
  });

  final int number;
  final String title;
  final String body;
  final Widget good;
  final Widget bad;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedNumeral(number),
        const SizedBox(height: Puls3Spacing.sm),
        Text(title, style: Puls3Text.h3),
        const SizedBox(height: Puls3Spacing.xs),
        Text(body, style: Puls3Text.bodyMuted),
      ],
    );
    final examples = BrandGrid(
      minTileWidth: 200,
      maxColumns: 2,
      children: [good, bad],
    );
    return Padding(
      key: ValueKey('dimension:$number'),
      padding: EdgeInsets.only(bottom: last ? 0 : Puls3Spacing.xxl),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 860
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: text),
                  const SizedBox(width: Puls3Spacing.xl),
                  Expanded(flex: 3, child: examples),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  text,
                  const SizedBox(height: Puls3Spacing.lg),
                  examples,
                ],
              ),
      ),
    );
  }
}

class _SafeSpace extends StatelessWidget {
  const _SafeSpace();

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'c is the diameter of the C01 center dot (0.072 × mark height). '
          'Keep a clear space of 4c, about 0.29 × mark height, on every side '
          'of the logo. Nothing else may enter it.',
          style: Puls3Text.body,
        ),
      ],
    );
    final diagram = Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.mdAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, c) => _Diagram(maxWidth: c.maxWidth),
          ),
          const SizedBox(height: Puls3Spacing.md),
          Text(
            'Safe space',
            style: Puls3Text.caption.copyWith(color: Puls3Colors.muted),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 860
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: text),
                const SizedBox(width: Puls3Spacing.xl),
                Expanded(flex: 3, child: diagram),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                text,
                const SizedBox(height: Puls3Spacing.lg),
                diagram,
              ],
            ),
    );
  }
}

class _Diagram extends StatelessWidget {
  const _Diagram({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    const space = BrandGeometry.clearSpaceC * BrandGeometry.centerDotRatio;
    final perMark =
        BrandGeometry.lockupSize(1).width + 2 * space; // width per mark px
    final markHeight = (maxWidth / perMark).clamp(16.0, 88.0);
    final c = BrandGeometry.c(markHeight);
    final margin = BrandGeometry.clearSpaceC * c;
    final logo = BrandGeometry.lockupSize(markHeight);
    final size = Size(logo.width + margin * 2, logo.height + margin * 2);
    final label = Puls3Text.caption.copyWith(color: Puls3Colors.accent);
    return SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        key: const ValueKey('safe-space-diagram'),
        painter: _SafeSpacePainter(margin: margin, c: c),
        child: Stack(
          children: [
            Positioned(
              left: margin,
              top: margin,
              child: LockupSample(
                markHeight: markHeight,
                halftone: markHeight >= BrandGeometry.halftoneMinMarkPx,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: margin,
              child: Center(child: Text('4c', style: label)),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: margin,
              child: Center(child: Text('4c', style: label)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The clear-space zone: a tinted margin of [margin] (4c) around the logo,
/// dashed outer and inner bounds, and a dashed grid of c across the margin.
class _SafeSpacePainter extends CustomPainter {
  const _SafeSpacePainter({required this.margin, required this.c});

  final double margin;
  final double c;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = outer.deflate(margin);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outer)
        ..addRect(inner),
      Paint()..color = Puls3Colors.accent.withValues(alpha: 0.08),
    );
    final grid = Paint()
      ..color = Puls3Colors.muted.withValues(alpha: 0.35)
      ..strokeWidth = 0.6;
    for (var i = 1; i < BrandGeometry.clearSpaceC; i++) {
      final d = c * i;
      for (final x in [outer.left + d, inner.right + d]) {
        drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), grid);
      }
      for (final y in [outer.top + d, inner.bottom + d]) {
        drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), grid);
      }
    }
    final edges = Paint()
      ..color = Puls3Colors.muted
      ..strokeWidth = 1;
    drawDashedRect(canvas, inner, edges);
    for (final x in [inner.left, inner.right]) {
      drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), edges);
    }
    for (final y in [inner.top, inner.bottom]) {
      drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), edges);
    }
    drawDashedRect(
      canvas,
      outer.deflate(0.5),
      Paint()
        ..color = Puls3Colors.accent
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SafeSpacePainter old) =>
      old.margin != margin || old.c != c;
}
