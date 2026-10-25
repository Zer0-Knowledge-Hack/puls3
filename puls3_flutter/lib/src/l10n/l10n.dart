import 'package:flutter/widgets.dart';
import 'package:puls3_flutter/l10n/generated/app_localizations.dart';

import '../domain/agent_filter.dart';
import '../domain/skill_display_name.dart';

export 'package:puls3_flutter/l10n/generated/app_localizations.dart';

/// Localized copy for the current [BuildContext].
extension AppL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Marketplace sort labels, kept out of the domain enum so the domain
/// package never imports Flutter l10n.
extension AgentSortL10n on AgentSort {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    AgentSort.featured => l10n.sortFeatured,
    AgentSort.priceLowToHigh => l10n.sortPriceLowToHigh,
    AgentSort.priceHighToLow => l10n.sortPriceHighToLow,
    AgentSort.topRated => l10n.sortTopRated,
  };
}

/// Localized label for a skill id or English display name.
String localizedSkillName(AppLocalizations l10n, String raw) {
  if (raw.isEmpty) return raw;
  return switch (canonicalSkillId(raw)) {
    'on-chain-analytics' => l10n.skillOnChainAnalytics,
    'monitoring' => l10n.skillMonitoring,
    'summaries' => l10n.skillSummaries,
    'payments' => l10n.skillPayments,
    'anchors' => l10n.skillAnchors,
    'compliance' => l10n.skillCompliance,
    'smart-contracts' => l10n.skillSmartContracts,
    'security' => l10n.skillSecurity,
    'rust' => l10n.skillRust,
    'document-parsing' => l10n.skillDocumentParsing,
    'accounting' => l10n.skillAccounting,
    'trading' => l10n.skillTrading,
    'copywriting' => l10n.skillCopywriting,
    'marketing' => l10n.skillMarketing,
    'customer-support' => l10n.skillCustomerSupport,
    'triage' => l10n.skillTriage,
    'data-cleaning' => l10n.skillDataCleaning,
    'research' => l10n.skillResearch,
    'generalist' => l10n.studioGeneralist,
    _ => skillDisplayName(raw),
  };
}

/// Bundled demo blurbs follow the UI locale. On-chain copy stays as published.
String localizedAgentDescription(
  AppLocalizations l10n,
  String id,
  String fallback,
) => switch (id) {
  'agt-001' => l10n.demoDescAgt001,
  'agt-002' => l10n.demoDescAgt002,
  'agt-003' => l10n.demoDescAgt003,
  'agt-004' => l10n.demoDescAgt004,
  'agt-005' => l10n.demoDescAgt005,
  'agt-006' => l10n.demoDescAgt006,
  'agt-007' => l10n.demoDescAgt007,
  'agt-008' => l10n.demoDescAgt008,
  _ => fallback,
};

/// Catalog sentinel for a missing model; brand names stay as published.
String localizedModelName(AppLocalizations l10n, String model) =>
    model == 'Unspecified' ? l10n.agentUnspecifiedModel : model;
