import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

/// A small pill for a skill or a filter. Tappable when [onTap] is provided,
/// removable when [onDelete] is provided, and smaller still when [dense]
/// (tags inside cards).
class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.dense = false,
    this.icon,
    this.onTap,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final bool dense;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Puls3Colors.onAccent : Puls3Colors.text;
    final fontSize = dense ? 11.0 : 12.5;
    return Material(
      color: selected
          ? Puls3Colors.accent
          : dense
          ? Puls3Colors.background
          : Puls3Colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Puls3Radius.pillAll,
        side: BorderSide(
          color: selected ? Puls3Colors.accent : Puls3Colors.hairline,
        ),
      ),
      child: InkWell(
        borderRadius: Puls3Radius.pillAll,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? Puls3Spacing.xs : 10,
            vertical: dense ? 3 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2, color: color),
                const SizedBox(width: Puls3Spacing.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Puls3Text.caption.copyWith(
                    color: dense && !selected ? Puls3Colors.muted : color,
                    fontSize: fontSize,
                  ),
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
