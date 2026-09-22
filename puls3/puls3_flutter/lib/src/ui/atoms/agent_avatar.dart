import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Circular avatar showing the agent's initial.
class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Puls3Colors.accent, Puls3Colors.secondary],
        ),
      ),
      child: Text(
        initial,
        style: Puls3Text.displayMd.copyWith(
          fontSize: size * 0.55,
          color: Puls3Colors.onAccent,
          height: 1,
        ),
      ),
    );
  }
}
