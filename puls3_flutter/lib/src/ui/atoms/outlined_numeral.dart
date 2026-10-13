import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A big two-digit numeral ("01") drawn as an outline.
class OutlinedNumeral extends StatelessWidget {
  const OutlinedNumeral(this.number, {super.key, this.size = 56});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = Puls3Text.h1;
    return Text(
      number.toString().padLeft(2, '0'),
      style: TextStyle(
        fontFamily: base.fontFamily,
        fontFamilyFallback: base.fontFamilyFallback,
        fontWeight: base.fontWeight,
        fontSize: size,
        height: 1,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Puls3Colors.muted,
      ),
    );
  }
}
