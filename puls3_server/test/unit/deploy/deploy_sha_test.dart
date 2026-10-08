import 'package:puls3_server/src/health/app_version.dart';
import 'package:test/test.dart';

import '../../../tool/deploy_sha.dart';

void main() {
  group('deployShaValue', () {
    test('is the short sha of a clean tree', () {
      expect(deployShaValue(sha: '63fbad2\n', dirty: false), '63fbad2');
    });

    test('marks a dirty tree with -dirty', () {
      expect(deployShaValue(sha: '63fbad2', dirty: true), '63fbad2-dirty');
    });

    test('rejects an empty sha', () {
      expect(() => deployShaValue(sha: ' \n', dirty: false), throwsStateError);
    });

    test('is accepted by the health version', () {
      for (final dirty in [false, true]) {
        final value = deployShaValue(sha: '63fbad2', dirty: dirty);
        expect(
          appVersionFromEnvironment({'PULS3_GIT_SHA': value}),
          '$packageVersion+$value',
        );
      }
    });
  });

  test('scloudSetShaArguments sets PULS3_GIT_SHA without prompting', () {
    expect(scloudSetShaArguments('63fbad2'), [
      '--non-interactive',
      'variable',
      'set',
      'PULS3_GIT_SHA',
      '63fbad2',
    ]);
  });
}
