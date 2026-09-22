import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/pulse_background.dart';

/// Success state: an animated check over the halftone pulse, a title, a
/// subtitle and arbitrary details/actions below.
class SuccessPanel extends StatelessWidget {
  const SuccessPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Puls3Radius.lgAll,
      child: PulseBackground(
        origin: const Alignment(0, -0.75),
        intensity: 0.9,
        spacing: 13,
        child: Padding(
          padding: const EdgeInsets.all(Puls3Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Puls3Colors.success,
                    boxShadow: [
                      BoxShadow(
                        color: Puls3Colors.success.withValues(alpha: 0.45),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Puls3Colors.onAccent,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: Puls3Spacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Puls3Text.displayMd,
              ),
              const SizedBox(height: Puls3Spacing.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Puls3Text.body,
              ),
              const SizedBox(height: Puls3Spacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
