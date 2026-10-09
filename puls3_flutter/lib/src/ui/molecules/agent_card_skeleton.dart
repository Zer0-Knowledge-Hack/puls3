import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/skeleton_box.dart';

/// The shape of an [AgentCard] while the catalog loads. Purely
/// presentational.
class AgentCardSkeleton extends StatelessWidget {
  const AgentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Puls3Spacing.lg),
      decoration: BoxDecoration(
        color: Puls3Colors.surface,
        borderRadius: Puls3Radius.lgAll,
        border: Border.all(color: Puls3Colors.hairline),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 40, height: 40),
              SizedBox(width: Puls3Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 16),
                    SizedBox(height: Puls3Spacing.xxs),
                    SkeletonBox(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Puls3Spacing.md),
          SkeletonBox(width: double.infinity),
          SizedBox(height: Puls3Spacing.xxs),
          SkeletonBox(width: 180),
          SizedBox(height: Puls3Spacing.md),
          Row(
            children: [
              SkeletonBox(width: 96, height: 24),
              Spacer(),
              SkeletonBox(width: 64, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}
