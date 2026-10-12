import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A vertical measuring ruler: a line with a tick at each end, as tall as
/// the painted size.
class RulerPainter extends CustomPainter {
  const RulerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final x = size.width / 2;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (final y in [0.5, size.height - 0.5]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(RulerPainter old) => old.color != color;
}

/// [child] with a ruler of [px] beside it and the measure below, as in
/// "24 px". [rulerTop] aligns the ruler with the measured part of [child].
class MeasuredSample extends StatelessWidget {
  const MeasuredSample({
    super.key,
    required this.px,
    required this.child,
    this.rulerTop = 0,
    this.color = Puls3Colors.muted,
  });

  final double px;
  final Widget child;
  final double rulerTop;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = '${px.round()} px';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: rulerTop),
              child: CustomPaint(
                key: ValueKey('ruler:${px.round()}'),
                size: Size(9, px),
                painter: RulerPainter(color: color),
              ),
            ),
            const SizedBox(width: Puls3Spacing.xs),
            child,
          ],
        ),
        const SizedBox(height: Puls3Spacing.xs),
        Text(label, style: Puls3Text.data.copyWith(color: color)),
      ],
    );
  }
}
