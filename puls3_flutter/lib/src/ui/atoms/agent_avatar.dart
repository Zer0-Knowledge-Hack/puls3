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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Puls3Colors.background,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: Text(
        initial,
        style: Puls3Text.h2.copyWith(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: Puls3Colors.accent,
          height: 1,
        ),
      ),
    );
  }
}
