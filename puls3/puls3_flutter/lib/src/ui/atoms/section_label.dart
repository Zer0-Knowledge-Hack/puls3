import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// Small uppercase label above a section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Puls3Text.overline.copyWith(color: color),
    );
  }
}
