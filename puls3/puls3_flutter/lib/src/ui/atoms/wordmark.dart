import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// The puls3 wordmark: display serif, with the "3" in the accent color.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 28, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = Puls3Text.wordmark.copyWith(fontSize: size);
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'puls', style: style),
          TextSpan(
            text: '3',
            style: style.copyWith(color: Puls3Colors.accent),
          ),
        ],
      ),
      semanticsLabel: 'puls3',
    );
    if (onTap == null) return text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: text),
    );
  }
}
