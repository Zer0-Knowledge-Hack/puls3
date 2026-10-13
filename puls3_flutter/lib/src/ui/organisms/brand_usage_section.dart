import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/brand_logo_samples.dart';
import '../molecules/brand_section.dart';
import '../molecules/rule_example_card.dart';

/// Mark height of the usage examples. Below 72 px, so they use the small
/// lockup files with the solid 3, as the rules require.
const double _m = 44;

const _paper = Color(0xFFF6F7F8);
const _stellarYellow = Color(0xFFFDDA24);

String _lockup(String colorway) =>
    brandAssetKey('svg/logo/puls3-logo-$colorway-small.svg');

/// "Usage Do's" and "Usage Don'ts" as rendered examples, from the usage and
/// misuse rules in docs/brand/README.md (sections 08 and 10).
class BrandUsageSection extends StatelessWidget {
  const BrandUsageSection({super.key});

  @override
  Widget build(BuildContext context) {
    const logo = LockupSample(markHeight: _m);
    final dos = [
      (
        'Use the official files, unaltered.',
        Puls3Colors.background,
        logo as Widget,
      ),
      (
        'Use the on-light files on light backgrounds.',
        _paper,
        LockupSample(markHeight: _m, asset: _lockup('light')),
      ),
      (
        'Switch to the small lockup and C01-small at small sizes.',
        Puls3Colors.background,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LockupSample(markHeight: 24),
            SizedBox(width: Puls3Spacing.lg),
            MarkSample(size: 16),
          ],
        ),
      ),
      (
        'Place the logo on calm, solid backgrounds.',
        const Color(0xFF6352CC),
        LockupSample(markHeight: _m, asset: _lockup('mono-white')),
      ),
    ];
    final donts = <(String, Color, Widget, Widget?)>[
      (
        "Don't recolor the logo.",
        Puls3Colors.surface,
        _tint(Puls3Colors.success, logo),
        null,
      ),
      (
        'Never recolor the logo with Stellar yellow (#FDDA24).',
        Puls3Colors.surface,
        _tint(_stellarYellow, logo),
        null,
      ),
      (
        "Don't outline the logo.",
        Puls3Colors.surface,
        const _Outlined(logo),
        null,
      ),
      (
        "Don't add shadows, glows or bevels.",
        _paper,
        _Shadowed(LockupSample(markHeight: _m, asset: _lockup('light'))),
        null,
      ),
      (
        "Don't fill the logo with a gradient.",
        Puls3Colors.surface,
        const _Gradient(logo),
        null,
      ),
      (
        "Don't stretch or distort the logo.",
        Puls3Colors.surface,
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1.35, 0.7, 1),
          child: logo,
        ),
        null,
      ),
      (
        "Don't rotate the logo.",
        Puls3Colors.surface,
        Transform.rotate(angle: -0.26, child: logo),
        null,
      ),
      (
        'Never place the logo on busy photos or patterns.',
        Puls3Colors.surface,
        logo,
        const CustomPaint(painter: _BusyPatternPainter()),
      ),
      (
        'Never use the dark-theme amber on white or paper (1.64:1).',
        _paper,
        _tint(Puls3Colors.accent, logo),
        null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandSection(
          title: "Usage Do's",
          child: BrandGrid(
            children: [
              for (final (i, (caption, background, example)) in dos.indexed)
                RuleExampleCard(
                  key: ValueKey('usage-do:$i'),
                  good: true,
                  caption: caption,
                  background: background,
                  example: example,
                ),
            ],
          ),
        ),
        const SizedBox(height: Puls3Spacing.xxxl),
        BrandSection(
          title: "Usage Don'ts",
          child: BrandGrid(
            children: [
              for (final (i, (caption, background, example, backdrop))
                  in donts.indexed)
                RuleExampleCard(
                  key: ValueKey('usage-dont:$i'),
                  good: false,
                  caption: caption,
                  background: background,
                  backdrop: backdrop,
                  example: example,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _tint(Color color, Widget child) => ColorFiltered(
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  child: child,
);

/// The logo drawn as a lavender outline: tinted copies offset around a
/// copy filled with the card color.
class _Outlined extends StatelessWidget {
  const _Outlined(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const d = 1.5;
    return Stack(
      children: [
        for (final offset in const [
          Offset(-d, 0),
          Offset(d, 0),
          Offset(0, -d),
          Offset(0, d),
          Offset(-d, -d),
          Offset(d, d),
          Offset(-d, d),
          Offset(d, -d),
        ])
          Transform.translate(
            offset: offset,
            child: _tint(Puls3Colors.lavender, child),
          ),
        _tint(Puls3Colors.surface, child),
      ],
    );
  }
}

class _Shadowed extends StatelessWidget {
  const _Shadowed(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.translate(
          offset: const Offset(4, 6),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: _tint(Puls3Colors.background.withValues(alpha: 0.6), child),
          ),
        ),
        child,
      ],
    );
  }
}

class _Gradient extends StatelessWidget {
  const _Gradient(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Puls3Colors.success, Puls3Colors.lavender],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Diagonal stripes and dots: a stand-in for a busy photo or pattern.
class _BusyPatternPainter extends CustomPainter {
  const _BusyPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stripe = Paint()
      ..color = Puls3Colors.lavender.withValues(alpha: 0.35)
      ..strokeWidth = 6;
    for (var x = -size.height; x < size.width; x += 18) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    final dot = Paint()..color = Puls3Colors.accent.withValues(alpha: 0.5);
    for (var y = 8.0; y < size.height; y += 22) {
      for (var x = 8.0; x < size.width; x += 22) {
        canvas.drawCircle(Offset(x, y), 3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_BusyPatternPainter old) => false;
}
