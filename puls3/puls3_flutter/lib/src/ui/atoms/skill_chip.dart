import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A small pill for a skill. Tappable when [onTap] is provided and
/// removable when [onDelete] is provided.
class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Puls3Colors.onAccent : Puls3Colors.text;
    return Material(
      color: selected ? Puls3Colors.accent : Puls3Colors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: Puls3Radius.pillAll,
        side: BorderSide(
          color: selected ? Puls3Colors.accent : Puls3Colors.border,
        ),
      ),
      child: InkWell(
        borderRadius: Puls3Radius.pillAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Puls3Spacing.sm,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Puls3Text.label.copyWith(color: color),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: Puls3Spacing.xxs),
                InkWell(
                  onTap: onDelete,
                  customBorder: const CircleBorder(),
                  child: Icon(Icons.close_rounded, size: 14, color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
