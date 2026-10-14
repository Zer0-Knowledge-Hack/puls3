import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/brand/brand_policy.dart';

void main() {
  test('the policy copy is marked as a draft for review', () {
    final source = File('lib/src/brand/brand_policy.dart').readAsStringSync();
    expect(
      source.trimLeft(),
      startsWith('// DRAFT: pending brand-owner approval.'),
    );
  });

  test('approved wording is listed and no contact is invented', () {
    expect(BrandPolicy.approvedPhrases, [
      'Built with puls3',
      'Available on puls3',
      'Powered by puls3',
    ]);
    expect(BrandPolicy.contactEmail, isNull);
    expect(BrandPolicy.expectations, isNotEmpty);
  });
}
