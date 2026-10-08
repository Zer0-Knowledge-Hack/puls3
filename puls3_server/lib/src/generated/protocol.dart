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
import 'package:puls3_server/src/generated/agent/agent_summary.dart'
    as _ih3rdrku;
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'agent/agent_catalog_unavailable.dart' as _it6c3ckv;
import 'agent/agent_summary.dart' as _ipe500bk;
import 'agent/agent_wallet.dart' as _ickya0iq;
import 'chain/chain_submission.dart' as _iz6hnyrm;
import 'greetings/greeting.dart' as _izw8z7ou;
import 'health/backend_health.dart' as _ikpil6ki;
import 'hire/agent_unavailable.dart' as _i3db3d86;
import 'hire/hire.dart' as _ikb6z54u;
import 'hire/hire_configuration_missing.dart' as _izyyjkbb;
import 'hire/hire_ledger_unavailable.dart' as _izuscvxu;
import 'hire/hire_payment.dart' as _i7gyvijy;
import 'hire/hire_request_invalid.dart' as _i1txwkfs;
import 'hire/hire_view.dart' as _ivruwodq;
export 'agent/agent_catalog_unavailable.dart';
export 'agent/agent_summary.dart';
export 'agent/agent_wallet.dart';
export 'chain/chain_submission.dart';
export 'greetings/greeting.dart';
export 'health/backend_health.dart';
export 'hire/agent_unavailable.dart';
export 'hire/hire.dart';
export 'hire/hire_configuration_missing.dart';
export 'hire/hire_ledger_unavailable.dart';
export 'hire/hire_payment.dart';
export 'hire/hire_request_invalid.dart';
export 'hire/hire_view.dart';

class Protocol extends _is.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'agent_wallet',
      dartName: 'AgentWallet',
      schema: 'public',
      module: 'puls3',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'owner',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'address',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'ciphertext',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'nonce',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'mac',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'keyVersion',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'agentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'agent_wallet_address_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'address',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'agent_wallet_owner_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'owner',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'chain_submission',
      dartName: 'ChainSubmission',
      schema: 'public',
      module: 'puls3',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'preparationId',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'purpose',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'transaction',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'state',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'errorCode',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'explorerUrl',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'hireId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'signedEnvelopeXdr',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'validUntil',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'lastSentAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'sendAttempts',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'lastCheckedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'chain_submission_preparation_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'preparationId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'chain_submission_transaction_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'transaction',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'chain_submission_state_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'state',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'lastCheckedAt',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'chain_submission_hire_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'hireId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'hire',
      dartName: 'HireRecord',
      schema: 'public',
      module: 'puls3',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'consumer',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'agentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'price',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'manifestVersion',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'expiredAt',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'hire_payment',
      dartName: 'HirePaymentRecord',
      schema: 'public',
      module: 'puls3',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'hireId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'transactionHash',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'jobId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'payer',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'payee',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'amount',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'hire_id',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'hireId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'transaction_hash',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'transactionHash',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'job_id',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'jobId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._iais.Protocol.targetTableDefinitions,
    ..._iacs.Protocol.targetTableDefinitions,
    ..._isp.Protocol.targetTableDefinitions,
  ];

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
      } on _is.DeserializationClassNameNotFoundException catch (_) {
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
    if (t == _ickya0iq.AgentWallet) {
      return _ickya0iq.AgentWallet.fromJson(data) as T;
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
    if (t == _ikb6z54u.HireRecord) {
      return _ikb6z54u.HireRecord.fromJson(data) as T;
    }
    if (t == _izyyjkbb.HireConfigurationMissing) {
      return _izyyjkbb.HireConfigurationMissing.fromJson(data) as T;
    }
    if (t == _izuscvxu.HireLedgerUnavailable) {
      return _izuscvxu.HireLedgerUnavailable.fromJson(data) as T;
    }
    if (t == _i7gyvijy.HirePaymentRecord) {
      return _i7gyvijy.HirePaymentRecord.fromJson(data) as T;
    }
    if (t == _i1txwkfs.HireRequestInvalid) {
      return _i1txwkfs.HireRequestInvalid.fromJson(data) as T;
    }
    if (t == _ivruwodq.HireView) {
      return _ivruwodq.HireView.fromJson(data) as T;
    }
    if (t == _is.getType<_it6c3ckv.AgentCatalogUnavailable?>()) {
      return (data != null
              ? _it6c3ckv.AgentCatalogUnavailable.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ipe500bk.AgentSummary?>()) {
      return (data != null ? _ipe500bk.AgentSummary.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ickya0iq.AgentWallet?>()) {
      return (data != null ? _ickya0iq.AgentWallet.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iz6hnyrm.ChainSubmission?>()) {
      return (data != null ? _iz6hnyrm.ChainSubmission.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_izw8z7ou.Greeting?>()) {
      return (data != null ? _izw8z7ou.Greeting.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ikpil6ki.BackendHealth?>()) {
      return (data != null ? _ikpil6ki.BackendHealth.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i3db3d86.AgentUnavailable?>()) {
      return (data != null ? _i3db3d86.AgentUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ikb6z54u.HireRecord?>()) {
      return (data != null ? _ikb6z54u.HireRecord.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_izyyjkbb.HireConfigurationMissing?>()) {
      return (data != null
              ? _izyyjkbb.HireConfigurationMissing.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_izuscvxu.HireLedgerUnavailable?>()) {
      return (data != null
              ? _izuscvxu.HireLedgerUnavailable.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i7gyvijy.HirePaymentRecord?>()) {
      return (data != null ? _i7gyvijy.HirePaymentRecord.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i1txwkfs.HireRequestInvalid?>()) {
      return (data != null ? _i1txwkfs.HireRequestInvalid.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ivruwodq.HireView?>()) {
      return (data != null ? _ivruwodq.HireView.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_ih3rdrku.AgentSummary>) {
      return (data as List)
              .map((e) => deserialize<_ih3rdrku.AgentSummary>(e))
              .toList()
          as T;
    }
    try {
      return _iais.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iacs.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _isp.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _it6c3ckv.AgentCatalogUnavailable => 'AgentCatalogUnavailable',
      _ipe500bk.AgentSummary => 'AgentSummary',
      _ickya0iq.AgentWallet => 'AgentWallet',
      _iz6hnyrm.ChainSubmission => 'ChainSubmission',
      _izw8z7ou.Greeting => 'Greeting',
      _ikpil6ki.BackendHealth => 'BackendHealth',
      _i3db3d86.AgentUnavailable => 'AgentUnavailable',
      _ikb6z54u.HireRecord => 'HireRecord',
      _izyyjkbb.HireConfigurationMissing => 'HireConfigurationMissing',
      _izuscvxu.HireLedgerUnavailable => 'HireLedgerUnavailable',
      _i7gyvijy.HirePaymentRecord => 'HirePaymentRecord',
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
      case _ickya0iq.AgentWallet():
        return 'AgentWallet';
      case _iz6hnyrm.ChainSubmission():
        return 'ChainSubmission';
      case _izw8z7ou.Greeting():
        return 'Greeting';
      case _ikpil6ki.BackendHealth():
        return 'BackendHealth';
      case _i3db3d86.AgentUnavailable():
        return 'AgentUnavailable';
      case _ikb6z54u.HireRecord():
        return 'HireRecord';
      case _izyyjkbb.HireConfigurationMissing():
        return 'HireConfigurationMissing';
      case _izuscvxu.HireLedgerUnavailable():
        return 'HireLedgerUnavailable';
      case _i7gyvijy.HirePaymentRecord():
        return 'HirePaymentRecord';
      case _i1txwkfs.HireRequestInvalid():
        return 'HireRequestInvalid';
      case _ivruwodq.HireView():
        return 'HireView';
    }
    className = _iais.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
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
    if (dataClassName == 'AgentWallet') {
      return deserialize<_ickya0iq.AgentWallet>(data['data']);
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
    if (dataClassName == 'HireRecord') {
      return deserialize<_ikb6z54u.HireRecord>(data['data']);
    }
    if (dataClassName == 'HireConfigurationMissing') {
      return deserialize<_izyyjkbb.HireConfigurationMissing>(data['data']);
    }
    if (dataClassName == 'HireLedgerUnavailable') {
      return deserialize<_izuscvxu.HireLedgerUnavailable>(data['data']);
    }
    if (dataClassName == 'HirePaymentRecord') {
      return deserialize<_i7gyvijy.HirePaymentRecord>(data['data']);
    }
    if (dataClassName == 'HireRequestInvalid') {
      return deserialize<_i1txwkfs.HireRequestInvalid>(data['data']);
    }
    if (dataClassName == 'HireView') {
      return deserialize<_ivruwodq.HireView>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iais.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacs.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iais.Protocol().registerHostProtocol('puls3', this);
    _iacs.Protocol().registerHostProtocol('puls3', this);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iais.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _ickya0iq.AgentWallet:
        return _ickya0iq.AgentWallet.t;
      case _iz6hnyrm.ChainSubmission:
        return _iz6hnyrm.ChainSubmission.t;
      case _ikb6z54u.HireRecord:
        return _ikb6z54u.HireRecord.t;
      case _i7gyvijy.HirePaymentRecord:
        return _i7gyvijy.HirePaymentRecord.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

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
      return _iais.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
