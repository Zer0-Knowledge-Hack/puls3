import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Signature motif (brand guide page 12): a hex dot field whose dots shrink
/// away from one focal point.
///
/// Rules applied here:
/// - Scale: grid step 18 to 28 px, center dot at least 6 px.
/// - Density: one focal point, placed off the text block (corner or edge).
/// - Color: amber within 35% of the radius, lavender beyond.
/// - Opacity: 30% to 60% behind content.
/// - Motion: a calm, slow pulse. Still when the platform asks for reduced
///   motion.
class PulseBackground extends StatefulWidget {
  const PulseBackground({
    super.key,
    this.focalPoint = Alignment.bottomRight,
    this.gridStep = 22,
    this.opacity = 0.55,
    this.radiusFactor = 0.75,
    this.child,
  });

  /// Where the dense core sits. Keep it off the text block.
  final Alignment focalPoint;

  /// Distance between dot centers, clamped to 18 to 28 px.
  final double gridStep;

  /// Layer opacity, clamped to 0.3 to 0.6.
  final double opacity;

  /// Field radius as a fraction of the surface's longest side.
  final double radiusFactor;
  final Widget? child;

  @override
  State<PulseBackground> createState() => _PulseBackgroundState();
}

class _PulseBackgroundState extends State<PulseBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Puls3Durations.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: Opacity(
                opacity: widget.opacity.clamp(0.3, 0.6),
                child: CustomPaint(
                  painter: _HexPulsePainter(
                    progress: _controller,
                    focalPoint: widget.focalPoint,
                    gridStep: widget.gridStep.clamp(18.0, 28.0),
                    radiusFactor: widget.radiusFactor,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _HexPulsePainter extends CustomPainter {
  _HexPulsePainter({
    required this.progress,
    required this.focalPoint,
    required this.gridStep,
    required this.radiusFactor,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Alignment focalPoint;
  final double gridStep;
  final double radiusFactor;

  static const double _amberCore = 0.35;
  static const double _minDotRadius = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = focalPoint.alongSize(size);
    final reach = size.longestSide * radiusFactor;
    // Center dot diameter: at least 6 px, about half the grid step.
    final maxRadius = math.max(3.0, gridStep * 0.3);
    // Calm breathing: dots swell by at most 8% and back.
    final breath =
        1 + 0.08 * (0.5 - 0.5 * math.cos(progress.value * 2 * math.pi));

    final amber = Paint()..color = Puls3Colors.accent;
    final lavender = Paint()..color = Puls3Colors.lavender;

    // Hex lattice anchored on the focal point, so the core dot is centered.
    final rowStep = gridStep * math.sqrt(3) / 2;
    final firstRow = -(center.dy / rowStep).ceil();
    final lastRow = ((size.height - center.dy) / rowStep).ceil();
    for (var row = firstRow; row <= lastRow; row++) {
      final y = center.dy + row * rowStep;
      final xShift = row.isOdd ? gridStep / 2 : 0.0;
      final firstCol = -((center.dx + xShift) / gridStep).ceil();
      final lastCol = ((size.width - center.dx) / gridStep).ceil();
      for (var col = firstCol; col <= lastCol; col++) {
        final x = center.dx + xShift + col * gridStep;
        final distance = (Offset(x, y) - center).distance;
        final t = distance / reach;
        if (t >= 1) continue;
        final radius = maxRadius * math.pow(1 - t, 1.25) * breath;
        if (radius < _minDotRadius) continue;
        canvas.drawCircle(
          Offset(x, y),
          radius,
          t <= _amberCore ? amber : lavender,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HexPulsePainter oldDelegate) =>
      oldDelegate.focalPoint != focalPoint ||
      oldDelegate.gridStep != gridStep ||
      oldDelegate.radiusFactor != radiusFactor;
}
