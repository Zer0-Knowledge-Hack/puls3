import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A placeholder bar for a value that is not known yet. It has the size of
/// the value it stands for, so the layout does not jump when it arrives.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, this.height = 14});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          color: Puls3Colors.hairline,
          borderRadius: Puls3Radius.smAll,
        ),
      ),
    );
  }
}
