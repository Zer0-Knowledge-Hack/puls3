/// Display names for the skill ids the server catalog is known to emit.
const _knownSkillNames = {
  'on-chain-analytics': 'On-chain analytics',
  'monitoring': 'Monitoring',
  'summaries': 'Summaries',
  'payments': 'Payments',
  'anchors': 'Anchors',
  'compliance': 'Compliance',
  'smart-contracts': 'Smart contracts',
  'security': 'Security',
  'rust': 'Rust',
  'document-parsing': 'Document parsing',
  'accounting': 'Accounting',
  'trading': 'Trading',
  'copywriting': 'Copywriting',
  'marketing': 'Marketing',
  'customer-support': 'Customer support',
  'triage': 'Triage',
  'data-cleaning': 'Data cleaning',
};

/// Turns a kebab-case skill id into a readable label.
///
/// Known ids use the table above. Unknown ids replace hyphens with spaces and
/// uppercase only the first letter, so new server skills still read well.
String skillDisplayName(String id) {
  final known = _knownSkillNames[id];
  if (known != null) return known;
  if (id.isEmpty) return id;
  final spaced = id.replaceAll('-', ' ');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
