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
    this.holdsCoin = false,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final double glow;
  final bool holdsCoin;
  final bool locked;

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
            boxShadow: holdsCoin
                ? [
                    BoxShadow(
                      color: Puls3Colors.accent.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            locked ? Icons.lock_rounded : icon,
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

/// A miniature hire: tap Hire, USDC locks in escrow, then releases on accept.
class HireDemo extends StatefulWidget {
  const HireDemo({
    super.key,
    required this.agentName,
    required this.priceUsdcStroops,
  });

  final String agentName;
  final int priceUsdcStroops;

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
    duration: const Duration(milliseconds: 6400),
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

  /// 0 = wallet, 1 = escrow (parked during work), 2 = agent after accept.
  double _coinPos(double t) {
    if (t <= 0.08) return 0;
    if (t <= 0.34) {
      final u = Curves.easeInOutCubic.transform((t - 0.08) / 0.26);
      return u;
    }
    if (t <= 0.78) return 1;
    return 1 + Curves.easeInOutCubic.transform((t - 0.78) / 0.22);
  }

  int _beat(double t) {
    if (t < 0.10) return 0;
    if (t < 0.38) return 1;
    if (t < 0.58) return 2;
    if (t < 0.78) return 3;
    return 4;
  }

  (String, String) _copy(AppLocalizations l10n, double t) {
    final amount = formatUsdc(widget.priceUsdcStroops);
    return switch (_beat(t)) {
      0 => (l10n.landingHireSigning, l10n.landingHireWalletBody(amount)),
      1 => (l10n.landingHireLocking, l10n.landingHireLockBody),
      2 => (l10n.landingHireWorking, l10n.landingHireWorkBody),
      3 => (l10n.landingHireReview, l10n.landingHireReviewBody),
      _ => (l10n.landingHireDone, l10n.landingHireReleaseBody),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nodes = [
      (Icons.account_balance_wallet_outlined, l10n.landingBentoWallet),
      (Icons.shield_outlined, l10n.landingBentoEscrow),
      (Icons.smart_toy_outlined, l10n.landingBentoAgent),
    ];
    return BentoTile(
      padding: const EdgeInsets.all(Puls3Spacing.md),
      child: AnimatedBuilder(
        animation: Listenable.merge([_play, _nudge]),
        builder: (context, _) {
          final t = _play.value;
          final pos = _idle ? 0.0 : _coinPos(t);
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
              Row(
                children: [
                  for (var i = 0; i < nodes.length; i++) ...[
                    if (i > 0)
                      Expanded(
                        child: _Connector(
                          fill: (pos - (i - 1)).clamp(0.0, 1.0),
                          coinT: pos > i - 1 && pos < i ? pos - (i - 1) : -1,
                        ),
                      ),
                    _Node(
                      icon: nodes[i].$1,
                      label: nodes[i].$2,
                      glow: (1 - (pos - i).abs()).clamp(0.0, 1.0),
                      holdsCoin: (pos - i).abs() < 0.08,
                      locked: i == 1 && pos >= 0.92 && pos <= 1.08,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Puls3Spacing.sm),
              SizedBox(
                height: 80,
                child: AnimatedSwitcher(
                  duration: Puls3Durations.medium,
                  child: Text(
                    copy.$2,
                    key: ValueKey(copy.$2),
                    style: Puls3Text.body.copyWith(fontSize: 14, height: 1.4),
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
