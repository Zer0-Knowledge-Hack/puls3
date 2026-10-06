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

import 'package:serverpod/serverpod.dart' as _i1;

abstract class HireConfigurationMissing
    implements
        _i1.SerializableException,
        _i1.SerializableModel,
        _i1.ProtocolSerialization {
  HireConfigurationMissing._({required this.setting});

  factory HireConfigurationMissing({required String setting}) =
      _HireConfigurationMissingImpl;

  factory HireConfigurationMissing.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return HireConfigurationMissing(
      setting: jsonSerialization['setting'] as String,
    );
  }

  String setting;

  /// Returns a shallow copy of this [HireConfigurationMissing]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  HireConfigurationMissing copyWith({String? setting});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireConfigurationMissing',
      'setting': setting,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HireConfigurationMissing',
      'setting': setting,
    };
  }

  @override
  String toString() {
    return 'HireConfigurationMissing(setting: $setting)';
  }
}

class _HireConfigurationMissingImpl extends HireConfigurationMissing {
  _HireConfigurationMissingImpl({required String setting})
    : super._(setting: setting);

  /// Returns a shallow copy of this [HireConfigurationMissing]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  HireConfigurationMissing copyWith({String? setting}) {
    return HireConfigurationMissing(setting: setting ?? this.setting);
  }
}
