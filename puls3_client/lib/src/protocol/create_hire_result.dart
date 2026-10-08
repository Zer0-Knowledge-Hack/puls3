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

import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'hire.dart' as _i2;
import 'prepared_transaction.dart' as _i3;
import 'package:puls3_client/src/protocol/protocol.dart' as _i4;

/// Result of HireEndpoint.createHire: the persisted hire and, when the
/// create_job envelope could be prepared, the unsigned transaction the
/// session wallet must sign.
abstract class CreateHireResult implements _i1.SerializableModel {
  CreateHireResult._({
    required this.hire,
    this.preparedCreateJob,
  });

  factory CreateHireResult({
    required _i2.Hire hire,
    _i3.PreparedTransaction? preparedCreateJob,
  }) = _CreateHireResultImpl;

  factory CreateHireResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return CreateHireResult(
      hire: _i4.Protocol().deserialize<_i2.Hire>(jsonSerialization['hire']),
      preparedCreateJob: jsonSerialization['preparedCreateJob'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.PreparedTransaction>(
              jsonSerialization['preparedCreateJob'],
            ),
    );
  }

  _i2.Hire hire;

  /// The unsigned create_job preparation. Null when the hire already has a
  /// submitted or confirmed create_job.
  _i3.PreparedTransaction? preparedCreateJob;

  /// Returns a shallow copy of this [CreateHireResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CreateHireResult copyWith({
    _i2.Hire? hire,
    _i3.PreparedTransaction? preparedCreateJob,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CreateHireResult',
      'hire': hire.toJson(),
      if (preparedCreateJob != null)
        'preparedCreateJob': preparedCreateJob?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CreateHireResultImpl extends CreateHireResult {
  _CreateHireResultImpl({
    required _i2.Hire hire,
    _i3.PreparedTransaction? preparedCreateJob,
  }) : super._(
         hire: hire,
         preparedCreateJob: preparedCreateJob,
       );

  /// Returns a shallow copy of this [CreateHireResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CreateHireResult copyWith({
    _i2.Hire? hire,
    Object? preparedCreateJob = _Undefined,
  }) {
    return CreateHireResult(
      hire: hire ?? this.hire.copyWith(),
      preparedCreateJob: preparedCreateJob is _i3.PreparedTransaction?
          ? preparedCreateJob
          : this.preparedCreateJob?.copyWith(),
    );
  }
}
