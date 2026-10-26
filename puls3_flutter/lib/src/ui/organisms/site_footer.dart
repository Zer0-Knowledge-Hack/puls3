import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/project_links.dart';
import '../../l10n/l10n.dart';
import '../../theme/breakpoints.dart';
import '../../theme/puls3_theme.dart';
import '../atoms/content_width.dart';
import '../atoms/puls3_logo.dart';
import '../molecules/built_on_stellar.dart';

Future<void> _open(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Shared footer: product links, docs, GitHub, brand, version and the
/// Stellar lockup. Chrome stays in the header; this is where the rest lives.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = isCompactLayout(context);

    Widget column(String title, List<Widget> links) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Puls3Text.caption.copyWith(
            color: Puls3Colors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: Puls3Spacing.xs),
        ...links,
      ],
    );

    Widget link({
      required String label,
      required VoidCallback onTap,
      Key? key,
      bool external = false,
    }) => TextButton(
      key: key,
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Puls3Colors.text,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 36),
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Puls3Text.caption.copyWith(fontWeight: FontWeight.w600),
          ),
          if (external) ...[
            const SizedBox(width: 4),
            const Icon(Icons.north_east_rounded, size: 12),
          ],
        ],
      ),
    );

    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Puls3Logo(markHeight: 24),
        const SizedBox(height: Puls3Spacing.sm),
        Text(
          l10n.footerTestnet,
          style: Puls3Text.caption.copyWith(color: Puls3Colors.text),
        ),
        const SizedBox(height: Puls3Spacing.xxs),
        Text(
          l10n.footerDemo,
          style: Puls3Text.caption.copyWith(color: Puls3Colors.text),
        ),
      ],
    );

    final product = column(l10n.footerProduct, [
      link(
        label: l10n.navMarketplace,
        onTap: () => context.go('/market'),
      ),
      link(label: l10n.navStudio, onTap: () => context.go('/studio')),
    ]);

    final resources = column(l10n.footerResources, [
      link(
        key: const Key('footer-docs'),
        label: l10n.navDocs,
        onTap: () => _open(documentationUrl),
        external: true,
      ),
      link(
        key: const Key('footer-github'),
        label: l10n.navGitHub,
        onTap: () => _open(repositoryUrl),
        external: true,
      ),
      link(
        key: const Key('footer-issues'),
        label: l10n.footerIssues,
        onTap: () => _open(feedbackUrl),
        external: true,
      ),
      link(
        label: l10n.footerBrand,
        onTap: () => context.go('/brand'),
      ),
    ]);

    final meta = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Puls3Spacing.md,
      runSpacing: Puls3Spacing.xs,
      children: [
        const BuiltOnStellar(compact: true),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Puls3Colors.hairline)),
      ),
      padding: EdgeInsets.symmetric(
        vertical: compact ? Puls3Spacing.lg : Puls3Spacing.xxl,
      ),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              brand,
              const SizedBox(height: Puls3Spacing.lg),
              product,
              const SizedBox(height: Puls3Spacing.md),
              resources,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: brand),
                  Expanded(child: product),
                  Expanded(child: resources),
                ],
              ),
            const SizedBox(height: Puls3Spacing.lg),
            meta,
          ],
        ),
      ),
    );
  }
}
