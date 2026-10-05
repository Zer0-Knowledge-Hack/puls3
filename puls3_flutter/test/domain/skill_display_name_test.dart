import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/domain/skill_display_name.dart';

void main() {
  group('skillDisplayName', () {
    test('maps the 17 known ids through the table', () {
      const expected = {
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
      expect(expected, hasLength(17));
      expected.forEach((id, name) {
        expect(skillDisplayName(id), name, reason: id);
      });
    });

    test('unknown ids replace hyphens and uppercase the first letter', () {
      expect(skillDisplayName('yield-farming'), 'Yield farming');
      expect(skillDisplayName('quant'), 'Quant');
    });

    test('unknown ids keep the rest of the casing unchanged', () {
      expect(skillDisplayName('zk-proofSystems'), 'Zk proofSystems');
    });

    test('empty id returns an empty string', () {
      expect(skillDisplayName(''), '');
    });
  });
}
