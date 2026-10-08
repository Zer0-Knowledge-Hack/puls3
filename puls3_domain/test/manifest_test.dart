import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

/// Matches an [InvalidManifest] whose problem list equals [expected].
Matcher problems(List<ManifestProblem> expected) => throwsA(
  isA<InvalidManifest>().having((e) => e.problems, 'problems', expected),
);

void main() {
  group('I25 ManifestVersion', () {
    test('rejects 0 and negative numbers', () {
      for (final v in [0, -1]) {
        expect(
          () => ManifestVersion(v),
          problems([ManifestProblem.versionInvalid]),
          reason: '$v',
        );
      }
    });

    test('accepts 1 and larger', () {
      expect(ManifestVersion(1).value, 1);
      expect(ManifestVersion(42).value, 42);
    });

    test('first is 1', () {
      expect(ManifestVersion.first, ManifestVersion(1));
    });

    test('next is the following number and leaves the original alone', () {
      final v3 = ManifestVersion(3);
      expect(v3.next(), ManifestVersion(4));
      expect(v3.value, 3);
    });

    test('orders by value and has value equality', () {
      expect(ManifestVersion(2).compareTo(ManifestVersion(3)), lessThan(0));
      expect(ManifestVersion(3).compareTo(ManifestVersion(2)), greaterThan(0));
      expect(ManifestVersion(2), ManifestVersion(2));
      expect(ManifestVersion(2).hashCode, ManifestVersion(2).hashCode);
    });
  });

  group('InvalidManifest', () {
    test('carries the problems in order with a readable message', () {
      final e = InvalidManifest([
        ManifestProblem.nameMissing,
        ManifestProblem.priceMissing,
      ]);
      expect(e.problems, [
        ManifestProblem.nameMissing,
        ManifestProblem.priceMissing,
      ]);
      expect(e.message, contains('nameMissing'));
      expect(e.message, contains('priceMissing'));
    });

    test('problems list is unmodifiable', () {
      final e = InvalidManifest([ManifestProblem.nameMissing]);
      expect(
        () => e.problems.add(ManifestProblem.priceMissing),
        throwsA(anything),
      );
    });

    test('rejects an empty list', () {
      expect(() => InvalidManifest([]), throwsArgumentError);
    });
  });
}
