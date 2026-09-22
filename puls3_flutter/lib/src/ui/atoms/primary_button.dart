import 'package:flutter/material.dart';

import '../../theme/puls3_theme.dart';

enum PrimaryButtonVariant { filled, outline }

/// The main call-to-action button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = PrimaryButtonVariant.filled,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final PrimaryButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final filled = variant == PrimaryButtonVariant.filled;
    final foreground = filled ? Puls3Colors.onAccent : Puls3Colors.text;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Puls3Spacing.lg),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: Puls3Radius.pillAll),
      ),
      textStyle: WidgetStatePropertyAll(Puls3Text.button),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? Puls3Colors.muted
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (!filled) return Puls3Colors.transparent;
        if (states.contains(WidgetState.disabled)) return Puls3Colors.hairline;
        if (states.contains(WidgetState.hovered)) {
          return Color.lerp(Puls3Colors.accent, Puls3Colors.text, 0.15);
        }
        return Puls3Colors.accent;
      }),
      side: WidgetStatePropertyAll(
        filled
            ? BorderSide.none
            : const BorderSide(color: Puls3Colors.hairline, width: 1.2),
      ),
      overlayColor: WidgetStatePropertyAll(foreground.withValues(alpha: 0.08)),
    );

    return TextButton(
      style: style,
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Puls3Colors.muted,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if (isLoading || icon != null) const SizedBox(width: Puls3Spacing.xs),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
