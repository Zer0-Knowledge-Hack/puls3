import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Signature motif: a radial halftone dot field that pulses outward from
/// [origin], tinted from accent to lavender and fading into the background.
///
/// Honors the platform "reduce motion" setting by rendering a still frame.
class PulseBackground extends StatefulWidget {
  const PulseBackground({
    super.key,
    this.origin = const Alignment(0, -0.2),
    this.intensity = 1.0,
    this.spacing = 16,
    this.child,
  });

  final Alignment origin;

  /// Overall opacity multiplier, from 0 to 1.
  final double intensity;

  /// Distance between dot centers, in logical pixels.
  final double spacing;
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
      _controller.stop();
      _controller.value = 0.35;
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
              child: CustomPaint(
                painter: _HalftonePulsePainter(
                  progress: _controller,
                  origin: widget.origin,
                  intensity: widget.intensity.clamp(0.0, 1.0),
                  spacing: widget.spacing,
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

class _HalftonePulsePainter extends CustomPainter {
  _HalftonePulsePainter({
    required this.progress,
    required this.origin,
    required this.intensity,
    required this.spacing,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Alignment origin;
  final double intensity;
  final double spacing;

  static const double _wavelength = 150;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = origin.alongSize(size);
    final maxDistance = _farthestCorner(center, size);
    final reach = math.min(maxDistance, 900.0);
    final phase = progress.value * 2 * math.pi;
    final maxRadius = spacing * 0.34;
    final paint = Paint()..isAntiAlias = true;

    // Offset every other row for a classic halftone lattice.
    var row = 0;
    for (var y = spacing / 2; y < size.height; y += spacing * 0.866, row++) {
      final xOffset = row.isOdd ? spacing / 2 : 0.0;
      for (var x = xOffset + spacing / 2; x < size.width; x += spacing) {
        final dx = x - center.dx;
        final dy = y - center.dy;
        final distance = math.sqrt(dx * dx + dy * dy);
        final t = distance / reach;
        if (t >= 1) continue;

        final falloff = math.pow(1 - t, 1.6).toDouble();
        final wave = math.sin(distance / _wavelength * 2 * math.pi - phase);
        final pulse = 0.25 + 0.75 * math.max(0.0, wave);
        final radius =
            maxRadius * (0.3 + 0.7 * pulse) * (0.35 + 0.65 * falloff);
        final alpha = (0.08 + 0.5 * pulse) * falloff * intensity;
        if (alpha < 0.01) continue;

        paint.color = Color.lerp(
          Puls3Colors.accent,
          Puls3Colors.secondary,
          t,
        )!.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  double _farthestCorner(Offset c, Size s) {
    final corners = [
      Offset.zero,
      Offset(s.width, 0),
      Offset(0, s.height),
      Offset(s.width, s.height),
    ];
    return corners.map((p) => (p - c).distance).reduce(math.max);
  }

  @override
  bool shouldRepaint(_HalftonePulsePainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.intensity != intensity ||
      oldDelegate.spacing != spacing;
}
