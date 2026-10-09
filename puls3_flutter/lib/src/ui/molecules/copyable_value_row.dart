import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/puls3_theme.dart';
import '../atoms/skeleton_box.dart';

/// A label over a long value (hash, id, address) shown on one line,
/// shortened in the middle, with a copy button. While [value] is null a
/// skeleton of the same height holds its place.
class CopyableValueRow extends StatefulWidget {
  const CopyableValueRow({
    super.key,
    required this.label,
    required this.value,
    this.display,
    this.copyLabel,
  });

  final String label;

  /// The full value that is copied; null while unknown.
  final String? value;

  /// What is shown instead of [value], for example a shortened hash.
  final String? display;

  /// Accessible name of the copy button, e.g. "Copy transaction".
  final String? copyLabel;

  @override
  State<CopyableValueRow> createState() => _CopyableValueRowState();
}

class _CopyableValueRowState extends State<CopyableValueRow> {
  bool _copied = false;

  @override
  void didUpdateWidget(CopyableValueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _copied = false;
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final copyLabel = widget.copyLabel ?? 'Copy ${widget.label.toLowerCase()}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Puls3Spacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: Puls3Text.bodyMuted.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 20,
                  child: AnimatedSwitcher(
                    duration: Puls3Durations.medium,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: value == null
                        ? const Align(
                            key: ValueKey('skeleton'),
                            alignment: Alignment.centerLeft,
                            child: SkeletonBox(width: 160),
                          )
                        : Tooltip(
                            key: const ValueKey('value'),
                            message: value,
                            child: Text(
                              widget.display ?? value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Puls3Text.data,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // 48 px touch target, kept even while loading so nothing shifts.
          SizedBox.square(
            dimension: 48,
            child: value == null
                ? null
                : IconButton(
                    tooltip: _copied ? 'Copied' : copyLabel,
                    onPressed: () => _copy(value),
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 18,
                      color: _copied ? Puls3Colors.success : Puls3Colors.muted,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
