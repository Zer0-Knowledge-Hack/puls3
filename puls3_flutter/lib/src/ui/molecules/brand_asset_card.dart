import 'package:flutter/material.dart';

import '../../brand/brand_kit.dart';
import '../../theme/puls3_theme.dart';

/// A logo or mark variant, drawn on the background it is made for. The
/// download actions (PNG, SVG, Copy SVG) appear over the dimmed card on
/// hover, or on tap on touch screens.
class BrandAssetCard extends StatefulWidget {
  const BrandAssetCard({
    super.key,
    required this.variant,
    required this.onOpenFile,
    required this.onCopySvg,
    this.height = 260,
  });

  final BrandVariant variant;

  /// Opens a kit file by its path under `web/brand/`.
  final ValueChanged<String> onOpenFile;

  /// Copies the markup of the SVG at this path.
  final ValueChanged<String> onCopySvg;
  final double height;

  static const paper = Color(0xFFF6F7F8);

  @override
  State<BrandAssetCard> createState() => _BrandAssetCardState();
}

class _BrandAssetCardState extends State<BrandAssetCard> {
  bool _hovered = false;
  bool _pinned = false;

  bool get _revealed => _hovered || _pinned;

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final onLight = v.background == BrandBackground.light;
    return Semantics(
      button: true,
      label: v.label,
      hint: 'Show download options',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          key: ValueKey('brand-card:${v.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _pinned = !_pinned),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: onLight ? BrandAssetCard.paper : Puls3Colors.background,
              borderRadius: Puls3Radius.lgAll,
              border: Border.all(color: Puls3Colors.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Puls3Spacing.lg),
                  child: Center(child: _Preview(variant: v)),
                ),
                AnimatedOpacity(
                  opacity: _revealed ? 1 : 0,
                  duration: Puls3Durations.fast,
                  child: ColoredBox(
                    color: Puls3Colors.background.withValues(alpha: 0.72),
                  ),
                ),
                if (_revealed)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionPill(
                          key: ValueKey('download:${v.preview.path}'),
                          icon: Icons.download_rounded,
                          label: 'PNG',
                          tooltip: 'Download PNG (${v.preview.width} px)',
                          onPressed: () => widget.onOpenFile(v.preview.path),
                        ),
                        const SizedBox(height: Puls3Spacing.xs),
                        _ActionPill(
                          key: ValueKey('download:${v.svg}'),
                          icon: Icons.download_rounded,
                          label: 'SVG',
                          tooltip: 'Download SVG',
                          onPressed: () => widget.onOpenFile(v.svg),
                        ),
                        const SizedBox(height: Puls3Spacing.xs),
                        _ActionPill(
                          key: ValueKey('copy:${v.svg}'),
                          icon: Icons.copy_rounded,
                          label: 'Copy SVG',
                          tooltip: 'Copy SVG markup',
                          onPressed: () => widget.onCopySvg(v.svg),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.variant});

  final BrandVariant variant;

  @override
  Widget build(BuildContext context) {
    // The largest PNG, not the SVG: the kit SVGs nest the mark in an inner
    // <svg>, which flutter_svg does not draw. The mark is shown at a fixed
    // size; the lockup fills the card width, which keeps its mark near or
    // above the 72 px halftone-3 minimum.
    final isMark = variant.group == BrandGroup.mark;
    return Image.network(
      brandFileUrl(variant.preview.path).toString(),
      width: isMark ? 120 : null,
      height: isMark ? 120 : null,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) => Icon(
        Icons.image_outlined,
        color: variant.background == BrandBackground.light
            ? Puls3Colors.background
            : Puls3Colors.muted,
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: Puls3Colors.text,
          foregroundColor: Puls3Colors.background,
          shape: const RoundedRectangleBorder(
            borderRadius: Puls3Radius.pillAll,
          ),
          textStyle: Puls3Text.caption.copyWith(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: Puls3Spacing.md),
          minimumSize: const Size(128, 40),
        ),
      ),
    );
  }
}
