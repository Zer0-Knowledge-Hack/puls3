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
import 'create_hire_result.dart' as _i5;
import 'greetings/greeting.dart' as _i6;
import 'health/backend_health.dart' as _i7;
import 'hire.dart' as _i8;
import 'hire/agent_unavailable.dart' as _i9;
import 'hire/hire_configuration_missing.dart' as _i10;
import 'hire/hire_ledger_unavailable.dart' as _i11;
import 'hire/hire_request_invalid.dart' as _i12;
import 'hire/hire_view.dart' as _i13;
import 'hire_detail.dart' as _i14;
import 'payment.dart' as _i15;
import 'prepared_transaction.dart' as _i16;
import 'puls3_api_exception.dart' as _i17;
import 'package:puls3_client/src/protocol/agent/agent_summary.dart' as _i18;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i19;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i20;
export 'agent/agent_catalog_unavailable.dart';
export 'agent/agent_summary.dart';
export 'chain/chain_submission.dart';
export 'create_hire_result.dart';
export 'greetings/greeting.dart';
export 'health/backend_health.dart';
export 'hire.dart';
export 'hire/agent_unavailable.dart';
export 'hire/hire_configuration_missing.dart';
export 'hire/hire_ledger_unavailable.dart';
export 'hire/hire_request_invalid.dart';
export 'hire/hire_view.dart';
export 'hire_detail.dart';
export 'payment.dart';
export 'prepared_transaction.dart';
export 'puls3_api_exception.dart';
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
    if (t == _i5.CreateHireResult) {
      return _i5.CreateHireResult.fromJson(data) as T;
    }
    if (t == _i6.Greeting) {
      return _i6.Greeting.fromJson(data) as T;
    }
    if (t == _i7.BackendHealth) {
      return _i7.BackendHealth.fromJson(data) as T;
    }
    if (t == _i8.Hire) {
      return _i8.Hire.fromJson(data) as T;
    }
    if (t == _i9.AgentUnavailable) {
      return _i9.AgentUnavailable.fromJson(data) as T;
    }
    if (t == _i10.HireConfigurationMissing) {
      return _i10.HireConfigurationMissing.fromJson(data) as T;
    }
    if (t == _i11.HireLedgerUnavailable) {
      return _i11.HireLedgerUnavailable.fromJson(data) as T;
    }
    if (t == _i12.HireRequestInvalid) {
      return _i12.HireRequestInvalid.fromJson(data) as T;
    }
    if (t == _i13.HireView) {
      return _i13.HireView.fromJson(data) as T;
    }
    if (t == _i14.HireDetail) {
      return _i14.HireDetail.fromJson(data) as T;
    }
    if (t == _i15.Payment) {
      return _i15.Payment.fromJson(data) as T;
    }
    if (t == _i16.PreparedTransaction) {
      return _i16.PreparedTransaction.fromJson(data) as T;
    }
    if (t == _i17.Puls3ApiException) {
      return _i17.Puls3ApiException.fromJson(data) as T;
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
    if (t == _i1.getType<_i5.CreateHireResult?>()) {
      return (data != null ? _i5.CreateHireResult.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.Greeting?>()) {
      return (data != null ? _i6.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.BackendHealth?>()) {
      return (data != null ? _i7.BackendHealth.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.Hire?>()) {
      return (data != null ? _i8.Hire.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.AgentUnavailable?>()) {
      return (data != null ? _i9.AgentUnavailable.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.HireConfigurationMissing?>()) {
      return (data != null
              ? _i10.HireConfigurationMissing.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i11.HireLedgerUnavailable?>()) {
      return (data != null ? _i11.HireLedgerUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i12.HireRequestInvalid?>()) {
      return (data != null ? _i12.HireRequestInvalid.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i13.HireView?>()) {
      return (data != null ? _i13.HireView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.HireDetail?>()) {
      return (data != null ? _i14.HireDetail.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.Payment?>()) {
      return (data != null ? _i15.Payment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.PreparedTransaction?>()) {
      return (data != null ? _i16.PreparedTransaction.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i17.Puls3ApiException?>()) {
      return (data != null ? _i17.Puls3ApiException.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i18.AgentSummary>) {
      return (data as List)
              .map((e) => deserialize<_i18.AgentSummary>(e))
              .toList()
          as T;
    }
    try {
      return _i19.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i20.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.AgentCatalogUnavailable => 'AgentCatalogUnavailable',
      _i3.AgentSummary => 'AgentSummary',
      _i4.ChainSubmission => 'ChainSubmission',
      _i5.CreateHireResult => 'CreateHireResult',
      _i6.Greeting => 'Greeting',
      _i7.BackendHealth => 'BackendHealth',
      _i8.Hire => 'Hire',
      _i9.AgentUnavailable => 'AgentUnavailable',
      _i10.HireConfigurationMissing => 'HireConfigurationMissing',
      _i11.HireLedgerUnavailable => 'HireLedgerUnavailable',
      _i12.HireRequestInvalid => 'HireRequestInvalid',
      _i13.HireView => 'HireView',
      _i14.HireDetail => 'HireDetail',
      _i15.Payment => 'Payment',
      _i16.PreparedTransaction => 'PreparedTransaction',
      _i17.Puls3ApiException => 'Puls3ApiException',
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
      case _i5.CreateHireResult():
        return 'CreateHireResult';
      case _i6.Greeting():
        return 'Greeting';
      case _i7.BackendHealth():
        return 'BackendHealth';
      case _i8.Hire():
        return 'Hire';
      case _i9.AgentUnavailable():
        return 'AgentUnavailable';
      case _i10.HireConfigurationMissing():
        return 'HireConfigurationMissing';
      case _i11.HireLedgerUnavailable():
        return 'HireLedgerUnavailable';
      case _i12.HireRequestInvalid():
        return 'HireRequestInvalid';
      case _i13.HireView():
        return 'HireView';
      case _i14.HireDetail():
        return 'HireDetail';
      case _i15.Payment():
        return 'Payment';
      case _i16.PreparedTransaction():
        return 'PreparedTransaction';
      case _i17.Puls3ApiException():
        return 'Puls3ApiException';
    }
    className = _i19.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i20.Protocol().getClassNameForObject(data);
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
    if (dataClassName == 'CreateHireResult') {
      return deserialize<_i5.CreateHireResult>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i6.Greeting>(data['data']);
    }
    if (dataClassName == 'BackendHealth') {
      return deserialize<_i7.BackendHealth>(data['data']);
    }
    if (dataClassName == 'Hire') {
      return deserialize<_i8.Hire>(data['data']);
    }
    if (dataClassName == 'AgentUnavailable') {
      return deserialize<_i9.AgentUnavailable>(data['data']);
    }
    if (dataClassName == 'HireConfigurationMissing') {
      return deserialize<_i10.HireConfigurationMissing>(data['data']);
    }
    if (dataClassName == 'HireLedgerUnavailable') {
      return deserialize<_i11.HireLedgerUnavailable>(data['data']);
    }
    if (dataClassName == 'HireRequestInvalid') {
      return deserialize<_i12.HireRequestInvalid>(data['data']);
    }
    if (dataClassName == 'HireView') {
      return deserialize<_i13.HireView>(data['data']);
    }
    if (dataClassName == 'HireDetail') {
      return deserialize<_i14.HireDetail>(data['data']);
    }
    if (dataClassName == 'Payment') {
      return deserialize<_i15.Payment>(data['data']);
    }
    if (dataClassName == 'PreparedTransaction') {
      return deserialize<_i16.PreparedTransaction>(data['data']);
    }
    if (dataClassName == 'Puls3ApiException') {
      return deserialize<_i17.Puls3ApiException>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i19.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i20.Protocol().deserializeByClassName(data);
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
      return _i19.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i20.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
