import 'package:flutter/material.dart';

import '../../../theme/puls3_theme.dart';

/// How far a step of the puls3 flow is built, shown on every node so the
/// diagram never presents planned work as working.
enum FlowStepStatus {
  live('Live on testnet', Puls3Colors.success),
  inDevelopment('In development', Puls3Colors.accent),
  planned('Planned', Puls3Colors.muted);

  const FlowStepStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// One stage of the flow.
class FlowStep {
  const FlowStep({
    required this.title,
    required this.body,
    required this.icon,
    required this.status,
  });

  final String title;
  final String body;
  final IconData icon;
  final FlowStepStatus status;
}

/// The puls3 flow as a diagram: numbered nodes joined by directional
/// connectors, with a pulse that walks the flow one step at a time.
///
/// Wide screens: two rows of four, the second row read right to left, so
/// the flow turns down at the end of the first row (a "snake"). Phones: a
/// vertical timeline. With reduced motion the pulse stays off; the diagram
/// reads the same without it. Purely presentational.
class HowItWorksDiagram extends StatefulWidget {
  const HowItWorksDiagram({
    super.key,
    required this.steps,
    this.showStatus = false,
  });

  final List<FlowStep> steps;

  /// When true, each node shows live / in development / planned. The
  /// landing story hides that; the data still carries the status.
  final bool showStatus;

  /// From this width the diagram uses the two-row layout.
  static const double wideFrom = 900;

  @override
  State<HowItWorksDiagram> createState() => _HowItWorksDiagramState();
}

class _HowItWorksDiagramState extends State<HowItWorksDiagram>
    with SingleTickerProviderStateMixin {
  static const _stepDuration = Duration(milliseconds: 1400);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _stepDuration * widget.steps.length,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      container: true,
      label:
          'How puls3 works, in ${widget.steps.length} steps. Each step '
          'says whether it is live on testnet, in development or planned.',
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final n = widget.steps.length;
            final progress = _pulse.value * n;
            // The connector after step `active` carries the pulse.
            final active = reduced ? -1 : progress.floor() % n;
            final t = progress - progress.floor();
            return constraints.maxWidth >= HowItWorksDiagram.wideFrom
                ? _wide(active, t)
                : _narrow(active, t);
          },
        ),
      ),
    );
  }

  Widget _node(int i, int active) => _StepNode(
    number: i + 1,
    step: widget.steps[i],
    highlighted: i == active,
    showStatus: widget.showStatus,
  );

  /// A single row when there are few steps; otherwise two rows, the
  /// second running right to left.
  Widget _wide(int active, double t) {
    final steps = widget.steps;
    if (steps.length <= 4) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                _Connector(
                  axis: Axis.horizontal,
                  reversed: false,
                  pulse: _pulseAt(i - 1, active, t),
                ),
              Expanded(child: _node(i, active)),
            ],
          ],
        ),
      );
    }
    final perRow = (steps.length / 2).ceil();
    final first = [for (var i = 0; i < perRow; i++) i];
    final second = [for (var i = steps.length - 1; i >= perRow; i--) i];

    Widget row(List<int> order, {required bool reversed}) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < order.length; k++) ...[
            if (k > 0)
              _Connector(
                axis: Axis.horizontal,
                reversed: reversed,
                // Between order[k-1] and order[k]: the earlier step owns it.
                pulse: _pulseAt(
                  reversed ? order[k] : order[k - 1],
                  active,
                  t,
                ),
              ),
            Expanded(child: _node(order[k], active)),
          ],
          // Keeps the columns aligned when the second row is shorter.
          for (var k = order.length; k < perRow; k++) ...[
            const SizedBox(width: _Connector.length),
            const Expanded(child: SizedBox()),
          ],
        ],
      ),
    );

    return Column(
      children: [
        row(first, reversed: false),
        // The turn: from the last node of row one down to the next step.
        // Same columns as the rows above, so it sits under the last node.
        Row(
          children: [
            for (var k = 0; k < perRow - 1; k++) ...[
              const Expanded(child: SizedBox()),
              const SizedBox(width: _Connector.length),
            ],
            Expanded(
              child: Center(
                child: _Connector(
                  axis: Axis.vertical,
                  pulse: _pulseAt(perRow - 1, active, t),
                ),
              ),
            ),
          ],
        ),
        row(second, reversed: true),
      ],
    );
  }

  /// A vertical timeline.
  Widget _narrow(int active, double t) {
    final steps = widget.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _node(i, active),
          if (i < steps.length - 1)
            Center(
              child: _Connector(
                axis: Axis.vertical,
                pulse: _pulseAt(i, active, t),
              ),
            ),
        ],
      ],
    );
  }

  /// The pulse position (0..1) on the connector after [step], or null.
  double? _pulseAt(int step, int active, double t) => step == active ? t : null;
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.number,
    required this.step,
    required this.highlighted,
    required this.showStatus,
  });

  final int number;
  final FlowStep step;
  final bool highlighted;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final status = step.status;
    final accent = showStatus ? status.color : Puls3Colors.accent;
    return Semantics(
      label: 'Step $number: ${step.title}. ${step.body}',
      excludeSemantics: true,
      child: AnimatedContainer(
        key: Key('flow-step-$number'),
        duration: Puls3Durations.fast,
        padding: const EdgeInsets.all(Puls3Spacing.md),
        decoration: BoxDecoration(
          color: Puls3Colors.surface,
          borderRadius: Puls3Radius.mdAll,
          border: Border.all(
            color: highlighted ? accent : Puls3Colors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent),
                  ),
                  child: Text(
                    '$number',
                    style: Puls3Text.caption.copyWith(color: accent),
                  ),
                ),
                const SizedBox(width: Puls3Spacing.xs),
                Icon(step.icon, size: 18, color: Puls3Colors.muted),
                if (showStatus) ...[
                  const SizedBox(width: Puls3Spacing.xs),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _StatusPill(status: status),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Puls3Spacing.sm),
            Text(step.title, style: Puls3Text.title),
            const SizedBox(height: Puls3Spacing.xxs),
            Text(
              step.body,
              style: Puls3Text.bodyMuted.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final FlowStepStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Puls3Spacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: Puls3Radius.pillAll,
        border: Border.all(color: status.color.withValues(alpha: 0.6)),
      ),
      child: Text(
        status.label,
        style: Puls3Text.caption.copyWith(color: status.color, fontSize: 11),
      ),
    );
  }
}

/// A directional line between two nodes, with an arrow head and, while
/// [pulse] is set, a dot travelling along it.
class _Connector extends StatelessWidget {
  const _Connector({
    required this.axis,
    this.reversed = false,
    this.pulse,
  });

  static const double length = 32;

  final Axis axis;

  /// Points right to left (horizontal) instead of left to right.
  final bool reversed;
  final double? pulse;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return ExcludeSemantics(
      child: SizedBox(
        width: horizontal ? length : 24,
        height: horizontal ? null : length,
        child: CustomPaint(
          painter: _ConnectorPainter(
            horizontal: horizontal,
            reversed: reversed,
            pulse: pulse,
          ),
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.horizontal,
    required this.reversed,
    required this.pulse,
  });

  final bool horizontal;
  final bool reversed;
  final double? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Puls3Colors.hairline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    Offset at(double f) => horizontal
        ? Offset(
            reversed ? size.width * (1 - f) : size.width * f,
            size.height / 2,
          )
        : Offset(size.width / 2, size.height * f);
    final start = at(0.1);
    final end = at(0.9);
    canvas.drawLine(start, end, line);

    // Arrow head at the end.
    final head = Paint()
      ..color = Puls3Colors.muted
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final dir = (end - start) / (end - start).distance;
    final normal = Offset(-dir.dy, dir.dx);
    canvas.drawLine(end, end - dir * 6 + normal * 4, head);
    canvas.drawLine(end, end - dir * 6 - normal * 4, head);

    final p = pulse;
    if (p != null) {
      final dot = Paint()..color = Puls3Colors.accent;
      canvas.drawCircle(Offset.lerp(start, end, p)!, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.pulse != pulse ||
      old.horizontal != horizontal ||
      old.reversed != reversed;
}
