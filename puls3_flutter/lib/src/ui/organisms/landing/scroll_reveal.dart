import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/puls3_theme.dart';

/// Fades and slides [child] in the first time it enters the viewport.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 24),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Puls3Durations.medium,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  ScrollPosition? _position;
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _delay?.cancel();
      _controller.value = 1;
      return;
    }
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _position)) {
      _position?.removeListener(_check);
      _position = next;
      _position?.addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (!mounted || _controller.isCompleted || _controller.isAnimating) {
      return;
    }
    if (_delay != null) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final view = MediaQuery.sizeOf(context);
    if (origin.dy < view.height * 0.9) _play();
  }

  void _play() {
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delay = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(
            widget.offset.dx / 400,
            widget.offset.dy / 400,
          ),
          end: Offset.zero,
        ).animate(_t),
        child: widget.child,
      ),
    );
  }
}
