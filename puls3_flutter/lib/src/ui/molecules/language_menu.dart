import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/locale_controller.dart';
import '../../theme/puls3_theme.dart';

/// Four-language menu. Shows the current language; picking one calls
/// [onSelected]. Presentational: the container persists the choice.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({
    super.key,
    required this.locale,
    required this.onSelected,
    this.compact = false,
    this.iconOnly = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onSelected;

  /// Short language tag instead of the native name (top bar on phones).
  final bool compact;

  /// Icon only: the names live in the menu. Used where the bar is tight.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = compact ? _shortTag(locale) : _nativeName(l10n, locale);

    return PopupMenuButton<Locale>(
      key: const Key('language-menu'),
      tooltip: l10n.languageMenuTooltip,
      initialValue: locale,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in supportedAppLocales)
          PopupMenuItem(
            value: option,
            child: Text(_nativeName(l10n, option)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Puls3Spacing.xs,
          vertical: Puls3Spacing.xs,
        ),
        child: iconOnly
            ? const Icon(
                Icons.language_rounded,
                size: 20,
                color: Puls3Colors.muted,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 18,
                    color: Puls3Colors.muted,
                  ),
                  const SizedBox(width: Puls3Spacing.xs),
                  Text(
                    label,
                    style: Puls3Text.caption.copyWith(
                      fontSize: 13,
                      color: Puls3Colors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _nativeName(AppLocalizations l10n, Locale locale) {
  final tag = languageTag(locale);
  return switch (tag) {
    'es' => l10n.languageSpanish,
    'pt-BR' => l10n.languagePortugueseBrazil,
    'pt-PT' => l10n.languagePortuguesePortugal,
    _ => l10n.languageEnglish,
  };
}

String _shortTag(Locale locale) => switch (languageTag(locale)) {
  'es' => 'ES',
  'pt-BR' => 'PT-BR',
  'pt-PT' => 'PT-PT',
  _ => 'EN',
};
