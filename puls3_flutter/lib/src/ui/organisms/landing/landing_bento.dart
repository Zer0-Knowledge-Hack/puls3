import 'package:flutter/material.dart';

import '../../../domain/usdc.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/puls3_theme.dart';
import '../../atoms/primary_button.dart';

/// A surface tile for the landing bento grid.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          padding: padding ?? const EdgeInsets.all(Puls3Spacing.lg),
          decoration: BoxDecoration(
            color: Puls3Colors.surface,
            borderRadius: Puls3Radius.lgAll,
            border: Border.all(color: Puls3Colors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
    );
    if (onTap == null) return body;
    return Material(
      color: Puls3Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Puls3Radius.lgAll,
        child: body,
      ),
    );
  }
}

/// Wallet → escrow → agent, with a pulse that walks the path.
class EscrowDemo extends StatefulWidget {
  const EscrowDemo({super.key});

  @override
  State<EscrowDemo> createState() => _EscrowDemoState();
}

class _EscrowDemoState extends State<EscrowDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
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
    final l10n = context.l10n;
    final nodes = [
      (Icons.account_balance_wallet_outlined, l10n.landingBentoWallet),
      (Icons.shield_outlined, l10n.landingBentoEscrow),
      (Icons.smart_toy_outlined, l10n.landingBentoAgent),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.landingBentoEscrowTitle, style: Puls3Text.h3),
            const SizedBox(height: Puls3Spacing.xs),
            Text(l10n.landingBentoEscrowBody, style: Puls3Text.body),
            if (constraints.maxHeight.isFinite)
              const Spacer()
            else
              const SizedBox(height: Puls3Spacing.lg),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return Row(
                  children: [
                    for (var i = 0; i < nodes.length; i++) ...[
                      if (i > 0)
                        Expanded(
                          child: _Connector(
                            fill: ((_pulse.value * 3) - (i - 1)).clamp(0.0, 1.0),
                            coinT: _activeIndex == i
                                ? -1
                                : ((_pulse.value * 3) - (i - 1)).clamp(0.0, 1.0),
                          ),
                        ),
                      _Node(
                        icon: nodes[i].$1,
                        label: nodes[i].$2,
                        glow: _activeIndex == i ? 1 : 0,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  int get _activeIndex {
    if (!_pulse.isAnimating) return 1;
    return (_pulse.value * 3).floor().clamp(0, 2);
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.icon,
    required this.label,
    required this.glow,
  });

  final IconData icon;
  final String label;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(Puls3Colors.text, Puls3Colors.accent, glow)!;
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Puls3Colors.background,
            border: Border.all(
              color: color,
              width: 1.2 + glow * 0.8,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        const SizedBox(height: Puls3Spacing.xs),
        SizedBox(
          width: 64,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Puls3Text.caption.copyWith(
              color: Puls3Colors.text,
              fontWeight: glow > 0.5 ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.fill, required this.coinT});

  final double fill;
  /// 0–1 along this segment; negative if the coin is elsewhere.
  final double coinT;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: CustomPaint(painter: _ConnectorPainter(fill, coinT)),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.fill, this.coinT);

  final double fill;
  final double coinT;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final start = Offset(0, y);
    final end = Offset(size.width, y);
    final dim = Paint()
      ..color = Puls3Colors.text.withValues(alpha: 0.28)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, dim);
    if (fill > 0) {
      final lit = Paint()
        ..color = Puls3Colors.accent.withValues(alpha: 0.85)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, Offset(size.width * fill, y), lit);
    }
    if (coinT >= 0 && coinT <= 1) {
      final c = Offset(size.width * coinT, y);
      canvas.drawCircle(
        c,
        7,
        Paint()..color = Puls3Colors.accent.withValues(alpha: 0.25),
      );
      canvas.drawCircle(c, 5, Paint()..color = Puls3Colors.accent);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.coinT != coinT;
}

/// A miniature hire: six protocol beats, drawn so the picture carries
/// the story. Coin (USDC) and work packet move on different paths.
///
/// Beats match escrow: open job → funded/lock → work → submit →
/// review → complete. Each beat holds ~4.5s (brand calm pulse). Tap a
/// step to pause and read.
class HireDemo extends StatefulWidget {
  const HireDemo({
    super.key,
    required this.agentName,
    required this.priceUsdcStroops,
  });

  final String agentName;
  final int priceUsdcStroops;

  static const int beats = 6;
  static const Duration stepHold = Duration(milliseconds: 4500);

  @override
  State<HireDemo> createState() => _HireDemoState();
}

class _HireDemoState extends State<HireDemo> with TickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: HireDemo.stepHold * HireDemo.beats,
  );

  bool get _reduced =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _idle => _play.value == 0 && !_play.isAnimating;
  bool get _done => _play.value == 1 && !_play.isAnimating;
  bool get _running => _play.isAnimating;

  @override
  void initState() {
    super.initState();
    _play.addStatusListener((status) {
      if (status == AnimationStatus.completed) _syncNudge();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncNudge();
  }

  void _syncNudge() {
    if (_reduced || _running) {
      _nudge
        ..stop()
        ..value = 0;
      return;
    }
    if (!_nudge.isAnimating) _nudge.repeat(reverse: true);
  }

  @override
  void dispose() {
    _nudge.dispose();
    _play.dispose();
    super.dispose();
  }

  void _run() {
    _nudge
      ..stop()
      ..value = 0;
    if (_reduced) {
      _play.value = 1;
      setState(() {});
      return;
    }
    _play.forward(from: 0);
  }

  /// Jump to the hold of [beat] so the picture and copy stay readable.
  void _showBeat(int beat) {
    _nudge
      ..stop()
      ..value = 0;
    _play.stop();
    _play.value = (beat + 0.55) / HireDemo.beats;
    _syncNudge();
  }

  /// 0 = you, 1 = vault, 2 = agent after accept.
  double _coinPos(double t) {
    final beat = (t * HireDemo.beats).clamp(0.0, HireDemo.beats - 0.001);
    final i = beat.floor();
    final u = _travel(beat - i);
    return switch (i) {
      0 => 0,
      1 => u,
      2 || 3 || 4 => 1,
      _ => 1 + u,
    };
  }

  /// -1 hidden, 0 at agent, 1 at you.
  double _workPos(double t) {
    final beat = (t * HireDemo.beats).clamp(0.0, HireDemo.beats - 0.001);
    final i = beat.floor();
    final u = _travel(beat - i);
    return switch (i) {
      0 || 1 => -1,
      2 => 0,
      3 => u,
      _ => 1,
    };
  }

  double _travel(double local) =>
      Curves.easeInOutCubic.transform((local / 0.28).clamp(0.0, 1.0));

  int _beat(double t) =>
      (t * HireDemo.beats).floor().clamp(0, HireDemo.beats - 1);

  (String, String) _copy(AppLocalizations l10n, double t) {
    final amount = formatUsdc(widget.priceUsdcStroops);
    return switch (_beat(t)) {
      0 => (l10n.landingHireSigning, l10n.landingHireWalletBody(amount)),
      1 => (l10n.landingHireLocking, l10n.landingHireLockBody),
      2 => (l10n.landingHireWorking, l10n.landingHireWorkBody),
      3 => (l10n.landingHireDelivering, l10n.landingHireDeliverBody),
      4 => (l10n.landingHireReview, l10n.landingHireReviewBody),
      _ => (l10n.landingHireDone, l10n.landingHireReleaseBody),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [
      l10n.landingHireStepHire,
      l10n.landingHireStepLock,
      l10n.landingHireStepWork,
      l10n.landingHireStepDeliver,
      l10n.landingHireStepReview,
      l10n.landingHireStepPay,
    ];
    return BentoTile(
      padding: const EdgeInsets.all(Puls3Spacing.md),
      child: AnimatedBuilder(
        animation: Listenable.merge([_play, _nudge]),
        builder: (context, _) {
          final t = _play.value;
          final beat = _idle ? -1 : _beat(t);
          final coin = _idle ? 0.0 : _coinPos(t);
          final work = _idle ? -1.0 : _workPos(t);
          final locked = coin >= 0.92 && coin <= 1.08;
          final copy = _idle
              ? (l10n.landingHireTry, l10n.landingHireHint)
              : _copy(l10n, t);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _idle ? Icons.touch_app_rounded : Icons.circle,
                    size: _idle ? 16 : 8,
                    color: Puls3Colors.accent,
                  ),
                  const SizedBox(width: Puls3Spacing.xs),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Puls3Durations.medium,
                      child: Text(
                        copy.$1,
                        key: ValueKey(copy.$1),
                        style: Puls3Text.caption.copyWith(
                          color: Puls3Colors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Puls3Spacing.sm),
              Text(widget.agentName, style: Puls3Text.title),
              const SizedBox(height: 2),
              Text(
                '${formatUsdc(widget.priceUsdcStroops)} USDC',
                style: Puls3Text.data.copyWith(color: Puls3Colors.accent),
              ),
              const SizedBox(height: Puls3Spacing.md),
              SizedBox(
                height: 148,
                child: CustomPaint(
                  key: const Key('landing-hire-scene'),
                  painter: _HireScenePainter(
                    coinPos: coin,
                    workPos: work,
                    locked: locked,
                    working: beat == 2,
                    pulse: beat == 2 ? (t * HireDemo.beats) % 1 : 0,
                    youLabel: l10n.landingHireYou,
                    vaultLabel: l10n.landingBentoEscrow,
                    agentLabel: l10n.landingBentoAgent,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: Puls3Spacing.xs),
              _TokenLegend(
                usdc: l10n.landingHireLegendUsdc,
                work: l10n.landingHireLegendWork,
              ),
              const SizedBox(height: Puls3Spacing.sm),
              _StepRail(
                labels: steps,
                active: beat,
                onSelect: _running ? null : _showBeat,
              ),
              const SizedBox(height: Puls3Spacing.sm),
              SizedBox(
                height: 72,
                child: AnimatedSwitcher(
                  duration: Puls3Durations.medium,
                  child: Text(
                    copy.$2,
                    key: ValueKey(copy.$2),
                    style: Puls3Text.body.copyWith(
                      fontSize: 15,
                      height: 1.45,
                      color: Puls3Colors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Puls3Spacing.md),
              Transform.scale(
                scale: 1 + 0.04 * (_idle && !_reduced ? _nudge.value : 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: Puls3Radius.pillAll,
                    boxShadow: [
                      BoxShadow(
                        color: Puls3Colors.accent.withValues(
                          alpha: 0.45 * (_idle && !_reduced ? _nudge.value : 0),
                        ),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: PrimaryButton(
                    key: const Key('landing-hire-run'),
                    label: _done ? l10n.landingHireReplay : l10n.landingHireCta,
                    onPressed: _running ? null : _run,
                    expand: true,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TokenLegend extends StatelessWidget {
  const _TokenLegend({required this.usdc, required this.work});

  final String usdc;
  final String work;

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label, {bool disc = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (disc)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else
            Container(
              width: 9,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                  bottomRight: Radius.circular(5),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Puls3Text.caption.copyWith(color: Puls3Colors.text),
          ),
        ],
      );
    }

    return Row(
      children: [
        item(Puls3Colors.accent, usdc, disc: true),
        const SizedBox(width: Puls3Spacing.md),
        item(Puls3Colors.lavender, work),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({
    required this.labels,
    required this.active,
    required this.onSelect,
  });

  final List<String> labels;
  final int active;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 12,
                height: 2,
                margin: const EdgeInsets.only(bottom: 14),
                color: i <= active ? Puls3Colors.accent : Puls3Colors.hairline,
              ),
            _RailStop(
              index: i + 1,
              label: labels[i],
              lit: i == active,
              done: i < active,
              onTap: onSelect == null ? null : () => onSelect!(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailStop extends StatelessWidget {
  const _RailStop({
    required this.index,
    required this.label,
    required this.lit,
    required this.done,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool lit;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = lit || done ? Puls3Colors.accent : Puls3Colors.muted;
    final stop = Column(
      children: [
        Container(
          key: Key('landing-hire-step-$index'),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? Puls3Colors.accent : Puls3Colors.transparent,
            border: Border.all(color: color, width: lit ? 0 : 1.2),
          ),
          child: Text(
            '$index',
            style: Puls3Text.caption.copyWith(
              color: lit ? Puls3Colors.onAccent : color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Puls3Text.caption.copyWith(
            color: Puls3Colors.text,
            fontWeight: lit ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
    if (onTap == null) return stop;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: stop),
    );
  }
}

/// You, vault, agent. Gold disc = USDC (you → vault → agent). Lavender
/// packet = work (agent → you, under the vault, never through it).
class _HireScenePainter extends CustomPainter {
  _HireScenePainter({
    required this.coinPos,
    required this.workPos,
    required this.locked,
    required this.working,
    required this.pulse,
    required this.youLabel,
    required this.vaultLabel,
    required this.agentLabel,
  });

  final double coinPos;
  final double workPos;
  final bool locked;
  final bool working;
  final double pulse;
  final String youLabel;
  final String vaultLabel;
  final String agentLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final you = Offset(size.width * 0.16, size.height * 0.42);
    final vault = Offset(size.width * 0.50, size.height * 0.42);
    final agent = Offset(size.width * 0.84, size.height * 0.42);
    const r = 28.0;

    _line(canvas, you, vault, (coinPos).clamp(0.0, 1.0));
    _line(canvas, vault, agent, (coinPos - 1).clamp(0.0, 1.0));
    if (workPos >= 0) {
      _workPath(canvas, agent, you, size.height * 0.78, workPos);
    }

    _wallet(canvas, you, r, glow: coinPos < 0.12);
    _vault(canvas, vault, r, locked: locked, glow: (coinPos - 1).abs() < 0.12);
    _agent(canvas, agent, r, working: working, pulse: pulse);

    _label(canvas, youLabel, Offset(you.dx, you.dy + r + 16));
    _label(canvas, vaultLabel, Offset(vault.dx, vault.dy + r + 16));
    _label(canvas, agentLabel, Offset(agent.dx, agent.dy + r + 16));

    final coin = coinPos <= 1
        ? Offset.lerp(you, vault, coinPos)!
        : Offset.lerp(vault, agent, coinPos - 1)!;
    _coin(canvas, coin);

    if (workPos >= 0) {
      final along = _workAlong(agent, you, size.height * 0.78, workPos);
      _packet(canvas, along);
    }
  }

  void _line(Canvas canvas, Offset a, Offset b, double fill) {
    final dim = Paint()
      ..color = Puls3Colors.text.withValues(alpha: 0.28)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, dim);
    if (fill > 0) {
      final lit = Paint()
        ..color = Puls3Colors.accent.withValues(alpha: 0.9)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a, Offset.lerp(a, b, fill)!, lit);
    }
  }

  void _workPath(Canvas canvas, Offset from, Offset to, double y, double t) {
    final path = Path()
      ..moveTo(from.dx, from.dy + 18)
      ..quadraticBezierTo(
        (from.dx + to.dx) / 2,
        y,
        to.dx,
        to.dy + 18,
      );
    final dim = Paint()
      ..color = Puls3Colors.lavender.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, dim);
    if (t > 0) {
      final lit = Paint()
        ..color = Puls3Colors.lavender.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * t), lit);
      }
    }
  }

  Offset _workAlong(Offset from, Offset to, double y, double t) {
    final path = Path()
      ..moveTo(from.dx, from.dy + 18)
      ..quadraticBezierTo((from.dx + to.dx) / 2, y, to.dx, to.dy + 18);
    for (final metric in path.computeMetrics()) {
      return metric.getTangentForOffset(metric.length * t)!.position;
    }
    return from;
  }

  void _wallet(Canvas canvas, Offset c, double r, {required bool glow}) {
    _stationDisc(canvas, c, r, glow: glow);
    final wallet = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 28, height: 20),
      const Radius.circular(4),
    );
    final stroke = Paint()
      ..color = Puls3Colors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(wallet, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + const Offset(10, 0),
          width: 6,
          height: 8,
        ),
        const Radius.circular(1.5),
      ),
      stroke,
    );
  }

  void _vault(
    Canvas canvas,
    Offset c,
    double r, {
    required bool locked,
    required bool glow,
  }) {
    _stationDisc(canvas, c, r, glow: glow || locked);
    final shield = Path()
      ..moveTo(c.dx, c.dy - 16)
      ..lineTo(c.dx + 14, c.dy - 10)
      ..lineTo(c.dx + 12, c.dy + 4)
      ..quadraticBezierTo(c.dx, c.dy + 16, c.dx - 12, c.dy + 4)
      ..lineTo(c.dx - 14, c.dy - 10)
      ..close();
    final stroke = Paint()
      ..color = locked ? Puls3Colors.accent : Puls3Colors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(shield, stroke);
    if (locked) {
      final lock = Paint()
        ..color = Puls3Colors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawArc(
        Rect.fromCenter(center: c + const Offset(0, -1), width: 8, height: 8),
        3.14,
        3.14,
        false,
        lock,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c + const Offset(0, 5), width: 10, height: 8),
          const Radius.circular(1.5),
        ),
        Paint()..color = Puls3Colors.accent,
      );
    }
  }

  void _agent(
    Canvas canvas,
    Offset c,
    double r, {
    required bool working,
    required double pulse,
  }) {
    _stationDisc(canvas, c, r, glow: working);
    if (working) {
      final ring = Paint()
        ..color = Puls3Colors.lavender.withValues(alpha: 0.35 + 0.35 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(c, r + 4 + 6 * pulse, ring);
    }
    final head = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 22, height: 20),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      head,
      Paint()
        ..color = Puls3Colors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final eye = Paint()..color = Puls3Colors.lavender;
    canvas.drawCircle(c + const Offset(-5, -1), 2.2, eye);
    canvas.drawCircle(c + const Offset(5, -1), 2.2, eye);
  }

  void _stationDisc(Canvas canvas, Offset c, double r, {required bool glow}) {
    canvas.drawCircle(c, r, Paint()..color = Puls3Colors.background);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = glow ? Puls3Colors.accent : Puls3Colors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 2.2 : 1.4,
    );
    if (glow) {
      canvas.drawCircle(
        c,
        r + 5,
        Paint()
          ..color = Puls3Colors.accent.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
    }
  }

  void _coin(Canvas canvas, Offset c) {
    canvas.drawCircle(
      c,
      9,
      Paint()..color = Puls3Colors.accent.withValues(alpha: 0.28),
    );
    canvas.drawCircle(c, 6.5, Paint()..color = Puls3Colors.accent);
  }

  void _packet(Canvas canvas, Offset c) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: 16, height: 20),
      const Radius.circular(2),
    );
    canvas.drawRRect(rect, Paint()..color = Puls3Colors.lavender);
    final fold = Path()
      ..moveTo(c.dx + 2, c.dy - 10)
      ..lineTo(c.dx + 8, c.dy - 10)
      ..lineTo(c.dx + 8, c.dy - 4)
      ..close();
    canvas.drawPath(fold, Paint()..color = Puls3Colors.background);
  }

  void _label(Canvas canvas, String text, Offset c) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Puls3Colors.text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, Offset(c.dx - painter.width / 2, c.dy));
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _HireScenePainter old) =>
      old.coinPos != coinPos ||
      old.workPos != workPos ||
      old.locked != locked ||
      old.working != working ||
      old.pulse != pulse ||
      old.youLabel != youLabel ||
      old.vaultLabel != vaultLabel ||
      old.agentLabel != agentLabel;
}
