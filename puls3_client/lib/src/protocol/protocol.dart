/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:puls3_client/src/protocol/agent/agent_summary.dart'
    as _i78wn19p;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'agent/agent_catalog_unavailable.dart' as _it6c3ckv;
import 'agent/agent_summary.dart' as _ipe500bk;
import 'chain/chain_submission.dart' as _iz6hnyrm;
import 'greetings/greeting.dart' as _izw8z7ou;
import 'health/backend_health.dart' as _ikpil6ki;
import 'hire/agent_unavailable.dart' as _i3db3d86;
import 'hire/hire_configuration_missing.dart' as _izyyjkbb;
import 'hire/hire_ledger_unavailable.dart' as _izuscvxu;
import 'hire/hire_request_invalid.dart' as _i1txwkfs;
import 'hire/hire_view.dart' as _ivruwodq;
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

class Protocol extends _isc.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

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
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _it6c3ckv.AgentCatalogUnavailable) {
      return _it6c3ckv.AgentCatalogUnavailable.fromJson(data) as T;
    }
    if (t == _ipe500bk.AgentSummary) {
      return _ipe500bk.AgentSummary.fromJson(data) as T;
    }
    if (t == _iz6hnyrm.ChainSubmission) {
      return _iz6hnyrm.ChainSubmission.fromJson(data) as T;
    }
    if (t == _izw8z7ou.Greeting) {
      return _izw8z7ou.Greeting.fromJson(data) as T;
    }
    if (t == _ikpil6ki.BackendHealth) {
      return _ikpil6ki.BackendHealth.fromJson(data) as T;
    }
    if (t == _i3db3d86.AgentUnavailable) {
      return _i3db3d86.AgentUnavailable.fromJson(data) as T;
    }
    if (t == _izyyjkbb.HireConfigurationMissing) {
      return _izyyjkbb.HireConfigurationMissing.fromJson(data) as T;
    }
    if (t == _izuscvxu.HireLedgerUnavailable) {
      return _izuscvxu.HireLedgerUnavailable.fromJson(data) as T;
    }
    if (t == _i1txwkfs.HireRequestInvalid) {
      return _i1txwkfs.HireRequestInvalid.fromJson(data) as T;
    }
    if (t == _ivruwodq.HireView) {
      return _ivruwodq.HireView.fromJson(data) as T;
    }
    if (t == _isc.getType<_it6c3ckv.AgentCatalogUnavailable?>()) {
      return (data != null
              ? _it6c3ckv.AgentCatalogUnavailable.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_ipe500bk.AgentSummary?>()) {
      return (data != null ? _ipe500bk.AgentSummary.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iz6hnyrm.ChainSubmission?>()) {
      return (data != null ? _iz6hnyrm.ChainSubmission.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_izw8z7ou.Greeting?>()) {
      return (data != null ? _izw8z7ou.Greeting.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ikpil6ki.BackendHealth?>()) {
      return (data != null ? _ikpil6ki.BackendHealth.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i3db3d86.AgentUnavailable?>()) {
      return (data != null ? _i3db3d86.AgentUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_izyyjkbb.HireConfigurationMissing?>()) {
      return (data != null
              ? _izyyjkbb.HireConfigurationMissing.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_izuscvxu.HireLedgerUnavailable?>()) {
      return (data != null
              ? _izuscvxu.HireLedgerUnavailable.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i1txwkfs.HireRequestInvalid?>()) {
      return (data != null ? _i1txwkfs.HireRequestInvalid.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ivruwodq.HireView?>()) {
      return (data != null ? _ivruwodq.HireView.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i78wn19p.AgentSummary>) {
      return (data as List)
              .map((e) => deserialize<_i78wn19p.AgentSummary>(e))
              .toList()
          as T;
    }
    try {
      return _iaic.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iacc.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _it6c3ckv.AgentCatalogUnavailable => 'AgentCatalogUnavailable',
      _ipe500bk.AgentSummary => 'AgentSummary',
      _iz6hnyrm.ChainSubmission => 'ChainSubmission',
      _izw8z7ou.Greeting => 'Greeting',
      _ikpil6ki.BackendHealth => 'BackendHealth',
      _i3db3d86.AgentUnavailable => 'AgentUnavailable',
      _izyyjkbb.HireConfigurationMissing => 'HireConfigurationMissing',
      _izuscvxu.HireLedgerUnavailable => 'HireLedgerUnavailable',
      _i1txwkfs.HireRequestInvalid => 'HireRequestInvalid',
      _ivruwodq.HireView => 'HireView',
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
      case _it6c3ckv.AgentCatalogUnavailable():
        return 'AgentCatalogUnavailable';
      case _ipe500bk.AgentSummary():
        return 'AgentSummary';
      case _iz6hnyrm.ChainSubmission():
        return 'ChainSubmission';
      case _izw8z7ou.Greeting():
        return 'Greeting';
      case _ikpil6ki.BackendHealth():
        return 'BackendHealth';
      case _i3db3d86.AgentUnavailable():
        return 'AgentUnavailable';
      case _izyyjkbb.HireConfigurationMissing():
        return 'HireConfigurationMissing';
      case _izuscvxu.HireLedgerUnavailable():
        return 'HireLedgerUnavailable';
      case _i1txwkfs.HireRequestInvalid():
        return 'HireRequestInvalid';
      case _ivruwodq.HireView():
        return 'HireView';
    }
    className = _iaic.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacc.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
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
      return deserialize<_it6c3ckv.AgentCatalogUnavailable>(data['data']);
    }
    if (dataClassName == 'AgentSummary') {
      return deserialize<_ipe500bk.AgentSummary>(data['data']);
    }
    if (dataClassName == 'ChainSubmission') {
      return deserialize<_iz6hnyrm.ChainSubmission>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_izw8z7ou.Greeting>(data['data']);
    }
    if (dataClassName == 'BackendHealth') {
      return deserialize<_ikpil6ki.BackendHealth>(data['data']);
    }
    if (dataClassName == 'AgentUnavailable') {
      return deserialize<_i3db3d86.AgentUnavailable>(data['data']);
    }
    if (dataClassName == 'HireConfigurationMissing') {
      return deserialize<_izyyjkbb.HireConfigurationMissing>(data['data']);
    }
    if (dataClassName == 'HireLedgerUnavailable') {
      return deserialize<_izuscvxu.HireLedgerUnavailable>(data['data']);
    }
    if (dataClassName == 'HireRequestInvalid') {
      return deserialize<_i1txwkfs.HireRequestInvalid>(data['data']);
    }
    if (dataClassName == 'HireView') {
      return deserialize<_ivruwodq.HireView>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iaic.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacc.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iaic.Protocol().registerHostProtocol('puls3', this);
    _iacc.Protocol().registerHostProtocol('puls3', this);
  }

  @override
  String getModuleName() => 'puls3';

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
      return _iaic.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacc.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
