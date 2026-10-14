/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;

/// The answer of a Studio test run (api.md, TestRunResult).
abstract class TestRunResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  TestRunResult._({
    required this.output,
    required this.remainingDailyRuns,
  });

  factory TestRunResult({
    required String output,
    required int remainingDailyRuns,
  }) = _TestRunResultImpl;

  factory TestRunResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return TestRunResult(
      output: jsonSerialization['output'] as String,
      remainingDailyRuns: jsonSerialization['remainingDailyRuns'] as int,
    );
  }

  String output;

  /// Runs left for this builder today, after this one.
  int remainingDailyRuns;

  /// Returns a shallow copy of this [TestRunResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  TestRunResult copyWith({
    String? output,
    int? remainingDailyRuns,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TestRunResult',
      'output': output,
      'remainingDailyRuns': remainingDailyRuns,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'TestRunResult',
      'output': output,
      'remainingDailyRuns': remainingDailyRuns,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _TestRunResultImpl extends TestRunResult {
  _TestRunResultImpl({
    required String output,
    required int remainingDailyRuns,
  }) : super._(
         output: output,
         remainingDailyRuns: remainingDailyRuns,
       );

  /// Returns a shallow copy of this [TestRunResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  TestRunResult copyWith({
    String? output,
    int? remainingDailyRuns,
  }) {
    return TestRunResult(
      output: output ?? this.output,
      remainingDailyRuns: remainingDailyRuns ?? this.remainingDailyRuns,
    );
  }
}
