import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws a dashed straight line from [a] to [b] (construction guides,
/// rulers, the clear-space grid).
void drawDashedLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Paint paint, {
  double dash = 4,
  double gap = 4,
}) {
  final delta = b - a;
  final length = delta.distance;
  if (length == 0) return;
  final step = delta / length;
  for (var d = 0.0; d < length; d += dash + gap) {
    final end = math.min(d + dash, length);
    canvas.drawLine(a + step * d, a + step * end, paint);
  }
}

/// Draws the four sides of [rect] as dashed lines.
void drawDashedRect(Canvas canvas, Rect rect, Paint paint, {double dash = 4}) {
  drawDashedLine(canvas, rect.topLeft, rect.topRight, paint, dash: dash);
  drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint, dash: dash);
  drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint, dash: dash);
  drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint, dash: dash);
}

/// Thin dashed construction lines framing a centered square of [markSize]:
/// two horizontal lines across the full width at its top and bottom, and
/// two vertical lines at its sides running the full height.
class ConstructionGuidesPainter extends CustomPainter {
  const ConstructionGuidesPainter({
    required this.markSize,
    required this.color,
  });

  final double markSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final mark = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: markSize,
      height: markSize,
    );
    for (final y in [mark.top, mark.bottom]) {
      drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), paint);
    }
    for (final x in [mark.left, mark.right]) {
      drawDashedLine(canvas, Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(ConstructionGuidesPainter old) =>
      old.markSize != markSize || old.color != color;
}
