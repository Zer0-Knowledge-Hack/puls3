import 'dart:io';

import 'package:puls3_server/src/health/app_version.dart';
import 'package:test/test.dart';

void main() {
  group('appVersionFromEnvironment', () {
    test('is the package version when PULS3_GIT_SHA is unset or empty', () {
      expect(appVersionFromEnvironment(const {}), packageVersion);
      expect(
        appVersionFromEnvironment(const {'PULS3_GIT_SHA': ''}),
        packageVersion,
      );
    });

    test('appends PULS3_GIT_SHA as semver build metadata', () {
      expect(
        appVersionFromEnvironment(const {'PULS3_GIT_SHA': '63fbad2'}),
        '$packageVersion+63fbad2',
      );
    });

    test('rejects a value that is not a semver build identifier', () {
      for (final value in ['63fb ad2', 'a+b', 'feat/31', '63fbad2\n']) {
        expect(
          () => appVersionFromEnvironment({'PULS3_GIT_SHA': value}),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });

  test('packageVersion equals the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(packageVersion, match!.group(1));
  });
}
