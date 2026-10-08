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
import 'package:serverpod/protocol.dart' as _i2;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i3;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i4;
import 'agent/agent_catalog_unavailable.dart' as _i5;
import 'agent/agent_summary.dart' as _i6;
import 'chain/chain_submission.dart' as _i7;
import 'create_hire_result.dart' as _i8;
import 'greetings/greeting.dart' as _i9;
import 'health/backend_health.dart' as _i10;
import 'hire.dart' as _i11;
import 'hire/agent_unavailable.dart' as _i12;
import 'hire/escrow_preparation.dart' as _i13;
import 'hire/hire.dart' as _i14;
import 'hire/hire_configuration_missing.dart' as _i15;
import 'hire/hire_ledger_unavailable.dart' as _i16;
import 'hire/hire_payment.dart' as _i17;
import 'hire/hire_request_invalid.dart' as _i18;
import 'hire/hire_view.dart' as _i19;
import 'hire_detail.dart' as _i20;
import 'payment.dart' as _i21;
import 'prepared_transaction.dart' as _i22;
import 'puls3_api_exception.dart' as _i23;
import 'package:puls3_server/src/generated/agent/agent_summary.dart' as _i24;
export 'agent/agent_catalog_unavailable.dart';
export 'agent/agent_summary.dart';
export 'chain/chain_submission.dart';
export 'create_hire_result.dart';
export 'greetings/greeting.dart';
export 'health/backend_health.dart';
export 'hire.dart';
export 'hire/agent_unavailable.dart';
export 'hire/escrow_preparation.dart';
export 'hire/hire.dart';
export 'hire/hire_configuration_missing.dart';
export 'hire/hire_ledger_unavailable.dart';
export 'hire/hire_payment.dart';
export 'hire/hire_request_invalid.dart';
export 'hire/hire_view.dart';
export 'hire_detail.dart';
export 'payment.dart';
export 'prepared_transaction.dart';
export 'puls3_api_exception.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'chain_submission',
      dartName: 'ChainSubmission',
      schema: 'public',
      module: 'puls3',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'chain_submission_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'preparationId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'purpose',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'transaction',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'state',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'errorCode',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'explorerUrl',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'updatedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'hireId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'signedEnvelopeXdr',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'validUntil',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastSentAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'sendAttempts',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
          columnDefault: '0',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'lastCheckedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'chain_submission_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'chain_submission_preparation_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'preparationId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'chain_submission_transaction_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'transaction',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'chain_submission_state_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'state',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'lastCheckedAt',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'chain_submission_hire_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
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
    _i2.TableDefinition(
      name: 'escrow_preparation',
      dartName: 'EscrowPreparation',
      schema: 'public',
      module: 'puls3',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'escrow_preparation_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'preparationId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'hireId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'purpose',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'signer',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'unsignedEnvelopeXdr',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'transactionHash',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'validUntil',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'jobExpiredAt',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'rejectReason',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'createdAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'supersededAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'submittedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'escrow_preparation_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'escrow_preparation_id_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'preparationId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'escrow_preparation_hire_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'hireId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'escrow_preparation_transaction_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'transactionHash',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'hire',
      dartName: 'HireRecord',
      schema: 'public',
      module: 'puls3',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'hire_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'consumer',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'agentId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'price',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'manifestVersion',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'expiredAt',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'requestId',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'input',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'hire_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'hire_consumer_request_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'consumer',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'requestId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'hire_job_id_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
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
    _i2.TableDefinition(
      name: 'hire_payment',
      dartName: 'HirePaymentRecord',
      schema: 'public',
      module: 'puls3',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'hire_payment_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'hireId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'transactionHash',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'jobId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'payer',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'payee',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'amount',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'hire_payment_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'hire_id',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'hireId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'transaction_hash',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'transactionHash',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _i2.IndexDefinition(
          indexName: 'job_id',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
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
    ..._i3.Protocol.targetTableDefinitions,
    ..._i4.Protocol.targetTableDefinitions,
    ..._i2.Protocol.targetTableDefinitions,
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
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i5.AgentCatalogUnavailable) {
      return _i5.AgentCatalogUnavailable.fromJson(data) as T;
    }
    if (t == _i6.AgentSummary) {
      return _i6.AgentSummary.fromJson(data) as T;
    }
    if (t == _i7.ChainSubmission) {
      return _i7.ChainSubmission.fromJson(data) as T;
    }
    if (t == _i8.CreateHireResult) {
      return _i8.CreateHireResult.fromJson(data) as T;
    }
    if (t == _i9.Greeting) {
      return _i9.Greeting.fromJson(data) as T;
    }
    if (t == _i10.BackendHealth) {
      return _i10.BackendHealth.fromJson(data) as T;
    }
    if (t == _i11.Hire) {
      return _i11.Hire.fromJson(data) as T;
    }
    if (t == _i12.AgentUnavailable) {
      return _i12.AgentUnavailable.fromJson(data) as T;
    }
    if (t == _i13.EscrowPreparation) {
      return _i13.EscrowPreparation.fromJson(data) as T;
    }
    if (t == _i14.HireRecord) {
      return _i14.HireRecord.fromJson(data) as T;
    }
    if (t == _i15.HireConfigurationMissing) {
      return _i15.HireConfigurationMissing.fromJson(data) as T;
    }
    if (t == _i16.HireLedgerUnavailable) {
      return _i16.HireLedgerUnavailable.fromJson(data) as T;
    }
    if (t == _i17.HirePaymentRecord) {
      return _i17.HirePaymentRecord.fromJson(data) as T;
    }
    if (t == _i18.HireRequestInvalid) {
      return _i18.HireRequestInvalid.fromJson(data) as T;
    }
    if (t == _i19.HireView) {
      return _i19.HireView.fromJson(data) as T;
    }
    if (t == _i20.HireDetail) {
      return _i20.HireDetail.fromJson(data) as T;
    }
    if (t == _i21.Payment) {
      return _i21.Payment.fromJson(data) as T;
    }
    if (t == _i22.PreparedTransaction) {
      return _i22.PreparedTransaction.fromJson(data) as T;
    }
    if (t == _i23.Puls3ApiException) {
      return _i23.Puls3ApiException.fromJson(data) as T;
    }
    if (t == _i1.getType<_i5.AgentCatalogUnavailable?>()) {
      return (data != null ? _i5.AgentCatalogUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i6.AgentSummary?>()) {
      return (data != null ? _i6.AgentSummary.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.ChainSubmission?>()) {
      return (data != null ? _i7.ChainSubmission.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.CreateHireResult?>()) {
      return (data != null ? _i8.CreateHireResult.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.Greeting?>()) {
      return (data != null ? _i9.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.BackendHealth?>()) {
      return (data != null ? _i10.BackendHealth.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.Hire?>()) {
      return (data != null ? _i11.Hire.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.AgentUnavailable?>()) {
      return (data != null ? _i12.AgentUnavailable.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.EscrowPreparation?>()) {
      return (data != null ? _i13.EscrowPreparation.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.HireRecord?>()) {
      return (data != null ? _i14.HireRecord.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.HireConfigurationMissing?>()) {
      return (data != null
              ? _i15.HireConfigurationMissing.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i16.HireLedgerUnavailable?>()) {
      return (data != null ? _i16.HireLedgerUnavailable.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i17.HirePaymentRecord?>()) {
      return (data != null ? _i17.HirePaymentRecord.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.HireRequestInvalid?>()) {
      return (data != null ? _i18.HireRequestInvalid.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i19.HireView?>()) {
      return (data != null ? _i19.HireView.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i20.HireDetail?>()) {
      return (data != null ? _i20.HireDetail.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i21.Payment?>()) {
      return (data != null ? _i21.Payment.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i22.PreparedTransaction?>()) {
      return (data != null ? _i22.PreparedTransaction.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i23.Puls3ApiException?>()) {
      return (data != null ? _i23.Puls3ApiException.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i24.AgentSummary>) {
      return (data as List)
              .map((e) => deserialize<_i24.AgentSummary>(e))
              .toList()
          as T;
    }
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i4.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i5.AgentCatalogUnavailable => 'AgentCatalogUnavailable',
      _i6.AgentSummary => 'AgentSummary',
      _i7.ChainSubmission => 'ChainSubmission',
      _i8.CreateHireResult => 'CreateHireResult',
      _i9.Greeting => 'Greeting',
      _i10.BackendHealth => 'BackendHealth',
      _i11.Hire => 'Hire',
      _i12.AgentUnavailable => 'AgentUnavailable',
      _i13.EscrowPreparation => 'EscrowPreparation',
      _i14.HireRecord => 'HireRecord',
      _i15.HireConfigurationMissing => 'HireConfigurationMissing',
      _i16.HireLedgerUnavailable => 'HireLedgerUnavailable',
      _i17.HirePaymentRecord => 'HirePaymentRecord',
      _i18.HireRequestInvalid => 'HireRequestInvalid',
      _i19.HireView => 'HireView',
      _i20.HireDetail => 'HireDetail',
      _i21.Payment => 'Payment',
      _i22.PreparedTransaction => 'PreparedTransaction',
      _i23.Puls3ApiException => 'Puls3ApiException',
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
      case _i5.AgentCatalogUnavailable():
        return 'AgentCatalogUnavailable';
      case _i6.AgentSummary():
        return 'AgentSummary';
      case _i7.ChainSubmission():
        return 'ChainSubmission';
      case _i8.CreateHireResult():
        return 'CreateHireResult';
      case _i9.Greeting():
        return 'Greeting';
      case _i10.BackendHealth():
        return 'BackendHealth';
      case _i11.Hire():
        return 'Hire';
      case _i12.AgentUnavailable():
        return 'AgentUnavailable';
      case _i13.EscrowPreparation():
        return 'EscrowPreparation';
      case _i14.HireRecord():
        return 'HireRecord';
      case _i15.HireConfigurationMissing():
        return 'HireConfigurationMissing';
      case _i16.HireLedgerUnavailable():
        return 'HireLedgerUnavailable';
      case _i17.HirePaymentRecord():
        return 'HirePaymentRecord';
      case _i18.HireRequestInvalid():
        return 'HireRequestInvalid';
      case _i19.HireView():
        return 'HireView';
      case _i20.HireDetail():
        return 'HireDetail';
      case _i21.Payment():
        return 'Payment';
      case _i22.PreparedTransaction():
        return 'PreparedTransaction';
      case _i23.Puls3ApiException():
        return 'Puls3ApiException';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i4.Protocol().getClassNameForObject(data);
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
      return deserialize<_i5.AgentCatalogUnavailable>(data['data']);
    }
    if (dataClassName == 'AgentSummary') {
      return deserialize<_i6.AgentSummary>(data['data']);
    }
    if (dataClassName == 'ChainSubmission') {
      return deserialize<_i7.ChainSubmission>(data['data']);
    }
    if (dataClassName == 'CreateHireResult') {
      return deserialize<_i8.CreateHireResult>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i9.Greeting>(data['data']);
    }
    if (dataClassName == 'BackendHealth') {
      return deserialize<_i10.BackendHealth>(data['data']);
    }
    if (dataClassName == 'Hire') {
      return deserialize<_i11.Hire>(data['data']);
    }
    if (dataClassName == 'AgentUnavailable') {
      return deserialize<_i12.AgentUnavailable>(data['data']);
    }
    if (dataClassName == 'EscrowPreparation') {
      return deserialize<_i13.EscrowPreparation>(data['data']);
    }
    if (dataClassName == 'HireRecord') {
      return deserialize<_i14.HireRecord>(data['data']);
    }
    if (dataClassName == 'HireConfigurationMissing') {
      return deserialize<_i15.HireConfigurationMissing>(data['data']);
    }
    if (dataClassName == 'HireLedgerUnavailable') {
      return deserialize<_i16.HireLedgerUnavailable>(data['data']);
    }
    if (dataClassName == 'HirePaymentRecord') {
      return deserialize<_i17.HirePaymentRecord>(data['data']);
    }
    if (dataClassName == 'HireRequestInvalid') {
      return deserialize<_i18.HireRequestInvalid>(data['data']);
    }
    if (dataClassName == 'HireView') {
      return deserialize<_i19.HireView>(data['data']);
    }
    if (dataClassName == 'HireDetail') {
      return deserialize<_i20.HireDetail>(data['data']);
    }
    if (dataClassName == 'Payment') {
      return deserialize<_i21.Payment>(data['data']);
    }
    if (dataClassName == 'PreparedTransaction') {
      return deserialize<_i22.PreparedTransaction>(data['data']);
    }
    if (dataClassName == 'Puls3ApiException') {
      return deserialize<_i23.Puls3ApiException>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i3.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i4.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i3.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i4.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i7.ChainSubmission:
        return _i7.ChainSubmission.t;
      case _i13.EscrowPreparation:
        return _i13.EscrowPreparation.t;
      case _i14.HireRecord:
        return _i14.HireRecord.t;
      case _i17.HirePaymentRecord:
        return _i17.HirePaymentRecord.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
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
      return _i3.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i4.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
