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
import 'agent/agent_catalog_unavailable.dart' as _i2;
import 'agent/agent_summary.dart' as _i3;
import 'chain/chain_submission.dart' as _i4;
import 'greetings/greeting.dart' as _i5;
import 'health/backend_health.dart' as _i6;
import 'hire/agent_unavailable.dart' as _i7;
import 'hire/hire_configuration_missing.dart' as _i8;
import 'hire/hire_ledger_unavailable.dart' as _i9;
import 'hire/hire_request_invalid.dart' as _i10;
import 'hire/hire_view.dart' as _i11;
import 'package:puls3_client/src/protocol/agent/agent_summary.dart' as _i12;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i13;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i14;
export 'agent/agent_catalog_unavailable.dart';
export 'agent/agent_summary.dart';
export 'chain/chain_submission.dart';
export 'greetings/greeting.dart';
export 'health/backend_health.dart';
export 'hire/agent_unavailable.dart';
export 'hire/hire_configuration_missing.dart';
export 'hire/hire_ledger_unavailable.dart';
export 'hire/hire_request_invalid.dart';
export 'hire/hire_view.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i2.AgentCatalogUnavailable) {
      return _i2.AgentCatalogUnavailable.fromJson(data) as T;
    }
    if (t == _i3.AgentSummary) {
      return _i3.AgentSummary.fromJson(data) as T;
    }
    if (t == _i4.ChainSubmission) {
      return _i4.ChainSubmission.fromJson(data) as T;
    }
    if (t == _i5.Greeting) {
      return _i5.Greeting.fromJson(data) as T;
    }
    if (t == _i6.BackendHealth) {
      return _i6.BackendHealth.fromJson(data) as T;
    }
    if (t == _i7.AgentUnavailable) {
      return _i7.AgentUnavailable.fromJson(data) as T;
    }
    if (t == _i8.HireConfigurationMissing) {
      return _i8.HireConfigurationMissing.fromJson(data) as T;
    }
    if (t == _i9.HireLedgerUnavailable) {
      return _i9.HireLedgerUnavailable.fromJson(data) as T;
    }
    if (t == _i10.HireRequestInvalid) {
      return _i10.HireRequestInvalid.fromJson(data) as T;
    }
    if (t == _i11.HireView) {
      return _i11.HireView.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.AgentCatalogUnavailable?>()) {
      return (data != null ? _i2.AgentCatalogUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i3.AgentSummary?>()) {
      return (data != null ? _i3.AgentSummary.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.ChainSubmission?>()) {
      return (data != null ? _i4.ChainSubmission.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.Greeting?>()) {
      return (data != null ? _i5.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.BackendHealth?>()) {
      return (data != null ? _i6.BackendHealth.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.AgentUnavailable?>()) {
      return (data != null ? _i7.AgentUnavailable.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.HireConfigurationMissing?>()) {
      return (data != null ? _i8.HireConfigurationMissing.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i9.HireLedgerUnavailable?>()) {
      return (data != null ? _i9.HireLedgerUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i10.HireRequestInvalid?>()) {
      return (data != null ? _i10.HireRequestInvalid.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i11.HireView?>()) {
      return (data != null ? _i11.HireView.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i12.AgentSummary>) {
      return (data as List)
              .map((e) => deserialize<_i12.AgentSummary>(e))
              .toList()
          as T;
    }
    try {
      return _i13.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i14.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.AgentCatalogUnavailable => 'AgentCatalogUnavailable',
      _i3.AgentSummary => 'AgentSummary',
      _i4.ChainSubmission => 'ChainSubmission',
      _i5.Greeting => 'Greeting',
      _i6.BackendHealth => 'BackendHealth',
      _i7.AgentUnavailable => 'AgentUnavailable',
      _i8.HireConfigurationMissing => 'HireConfigurationMissing',
      _i9.HireLedgerUnavailable => 'HireLedgerUnavailable',
      _i10.HireRequestInvalid => 'HireRequestInvalid',
      _i11.HireView => 'HireView',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('puls3.', '');
    }

    switch (data) {
      case _i2.AgentCatalogUnavailable():
        return 'AgentCatalogUnavailable';
      case _i3.AgentSummary():
        return 'AgentSummary';
      case _i4.ChainSubmission():
        return 'ChainSubmission';
      case _i5.Greeting():
        return 'Greeting';
      case _i6.BackendHealth():
        return 'BackendHealth';
      case _i7.AgentUnavailable():
        return 'AgentUnavailable';
      case _i8.HireConfigurationMissing():
        return 'HireConfigurationMissing';
      case _i9.HireLedgerUnavailable():
        return 'HireLedgerUnavailable';
      case _i10.HireRequestInvalid():
        return 'HireRequestInvalid';
      case _i11.HireView():
        return 'HireView';
    }
    className = _i13.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i14.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AgentCatalogUnavailable') {
      return deserialize<_i2.AgentCatalogUnavailable>(data['data']);
    }
    if (dataClassName == 'AgentSummary') {
      return deserialize<_i3.AgentSummary>(data['data']);
    }
    if (dataClassName == 'ChainSubmission') {
      return deserialize<_i4.ChainSubmission>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i5.Greeting>(data['data']);
    }
    if (dataClassName == 'BackendHealth') {
      return deserialize<_i6.BackendHealth>(data['data']);
    }
    if (dataClassName == 'AgentUnavailable') {
      return deserialize<_i7.AgentUnavailable>(data['data']);
    }
    if (dataClassName == 'HireConfigurationMissing') {
      return deserialize<_i8.HireConfigurationMissing>(data['data']);
    }
    if (dataClassName == 'HireLedgerUnavailable') {
      return deserialize<_i9.HireLedgerUnavailable>(data['data']);
    }
    if (dataClassName == 'HireRequestInvalid') {
      return deserialize<_i10.HireRequestInvalid>(data['data']);
    }
    if (dataClassName == 'HireView') {
      return deserialize<_i11.HireView>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i13.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i14.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i13.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i14.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
