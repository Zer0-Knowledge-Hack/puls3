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

/// Server-only deploy of one Studio draft. The client sees [DeploySession].
abstract class StudioDeployRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  StudioDeployRecord._({
    this.id,
    required this.draftId,
    required this.owner,
    required this.state,
    required this.agentWallet,
    required this.registrationUri,
    this.manifestJson,
    this.preparationId,
    this.unsignedEnvelopeXdr,
    this.authorizationEntryXdr,
    this.signatureExpirationLedger,
    this.registrationHash,
    this.walletTxHash,
    this.registryAgentId,
    this.expiresAt,
    this.failureCode,
    this.retryFromStep,
    this.walletAuthJson,
    required this.updatedAt,
  });

  factory StudioDeployRecord({
    int? id,
    required int draftId,
    required String owner,
    required String state,
    required String agentWallet,
    required String registrationUri,
    String? manifestJson,
    String? preparationId,
    String? unsignedEnvelopeXdr,
    String? authorizationEntryXdr,
    int? signatureExpirationLedger,
    String? registrationHash,
    String? walletTxHash,
    int? registryAgentId,
    DateTime? expiresAt,
    String? failureCode,
    int? retryFromStep,
    String? walletAuthJson,
    required DateTime updatedAt,
  }) = _StudioDeployRecordImpl;

  factory StudioDeployRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return StudioDeployRecord(
      id: jsonSerialization['id'] as int?,
      draftId: jsonSerialization['draftId'] as int,
      owner: jsonSerialization['owner'] as String,
      state: jsonSerialization['state'] as String,
      agentWallet: jsonSerialization['agentWallet'] as String,
      registrationUri: jsonSerialization['registrationUri'] as String,
      manifestJson: jsonSerialization['manifestJson'] as String?,
      preparationId: jsonSerialization['preparationId'] as String?,
      unsignedEnvelopeXdr: jsonSerialization['unsignedEnvelopeXdr'] as String?,
      authorizationEntryXdr:
          jsonSerialization['authorizationEntryXdr'] as String?,
      signatureExpirationLedger:
          jsonSerialization['signatureExpirationLedger'] as int?,
      registrationHash: jsonSerialization['registrationHash'] as String?,
      walletTxHash: jsonSerialization['walletTxHash'] as String?,
      registryAgentId: jsonSerialization['registryAgentId'] as int?,
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      failureCode: jsonSerialization['failureCode'] as String?,
      retryFromStep: jsonSerialization['retryFromStep'] as int?,
      walletAuthJson: jsonSerialization['walletAuthJson'] as String?,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = StudioDeployRecordTable();

  static const db = StudioDeployRecordRepository._();

  @override
  int? id;

  int draftId;

  String owner;

  String state;

  String agentWallet;

  String registrationUri;

  /// Draft document that was hashed and registered. The prompt stays here.
  String? manifestJson;

  String? preparationId;

  String? unsignedEnvelopeXdr;

  String? authorizationEntryXdr;

  int? signatureExpirationLedger;

  String? registrationHash;

  String? walletTxHash;

  int? registryAgentId;

  DateTime? expiresAt;

  String? failureCode;

  int? retryFromStep;

  /// JSON [WalletAuthDraft], enough to rebuild set_agent_wallet.
  String? walletAuthJson;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [StudioDeployRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StudioDeployRecord copyWith({
    int? id,
    int? draftId,
    String? owner,
    String? state,
    String? agentWallet,
    String? registrationUri,
    String? manifestJson,
    String? preparationId,
    String? unsignedEnvelopeXdr,
    String? authorizationEntryXdr,
    int? signatureExpirationLedger,
    String? registrationHash,
    String? walletTxHash,
    int? registryAgentId,
    DateTime? expiresAt,
    String? failureCode,
    int? retryFromStep,
    String? walletAuthJson,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StudioDeployRecord',
      if (id != null) 'id': id,
      'draftId': draftId,
      'owner': owner,
      'state': state,
      'agentWallet': agentWallet,
      'registrationUri': registrationUri,
      if (manifestJson != null) 'manifestJson': manifestJson,
      if (preparationId != null) 'preparationId': preparationId,
      if (unsignedEnvelopeXdr != null)
        'unsignedEnvelopeXdr': unsignedEnvelopeXdr,
      if (authorizationEntryXdr != null)
        'authorizationEntryXdr': authorizationEntryXdr,
      if (signatureExpirationLedger != null)
        'signatureExpirationLedger': signatureExpirationLedger,
      if (registrationHash != null) 'registrationHash': registrationHash,
      if (walletTxHash != null) 'walletTxHash': walletTxHash,
      if (registryAgentId != null) 'registryAgentId': registryAgentId,
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (failureCode != null) 'failureCode': failureCode,
      if (retryFromStep != null) 'retryFromStep': retryFromStep,
      if (walletAuthJson != null) 'walletAuthJson': walletAuthJson,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static StudioDeployRecordInclude include() {
    return StudioDeployRecordInclude._();
  }

  static StudioDeployRecordIncludeList includeList({
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioDeployRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDeployRecordTable>? orderByList,
    StudioDeployRecordInclude? include,
  }) {
    return StudioDeployRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StudioDeployRecord.t),
      orderByList: orderByList?.call(StudioDeployRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StudioDeployRecordImpl extends StudioDeployRecord {
  _StudioDeployRecordImpl({
    int? id,
    required int draftId,
    required String owner,
    required String state,
    required String agentWallet,
    required String registrationUri,
    String? manifestJson,
    String? preparationId,
    String? unsignedEnvelopeXdr,
    String? authorizationEntryXdr,
    int? signatureExpirationLedger,
    String? registrationHash,
    String? walletTxHash,
    int? registryAgentId,
    DateTime? expiresAt,
    String? failureCode,
    int? retryFromStep,
    String? walletAuthJson,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         draftId: draftId,
         owner: owner,
         state: state,
         agentWallet: agentWallet,
         registrationUri: registrationUri,
         manifestJson: manifestJson,
         preparationId: preparationId,
         unsignedEnvelopeXdr: unsignedEnvelopeXdr,
         authorizationEntryXdr: authorizationEntryXdr,
         signatureExpirationLedger: signatureExpirationLedger,
         registrationHash: registrationHash,
         walletTxHash: walletTxHash,
         registryAgentId: registryAgentId,
         expiresAt: expiresAt,
         failureCode: failureCode,
         retryFromStep: retryFromStep,
         walletAuthJson: walletAuthJson,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [StudioDeployRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StudioDeployRecord copyWith({
    Object? id = _Undefined,
    int? draftId,
    String? owner,
    String? state,
    String? agentWallet,
    String? registrationUri,
    Object? manifestJson = _Undefined,
    Object? preparationId = _Undefined,
    Object? unsignedEnvelopeXdr = _Undefined,
    Object? authorizationEntryXdr = _Undefined,
    Object? signatureExpirationLedger = _Undefined,
    Object? registrationHash = _Undefined,
    Object? walletTxHash = _Undefined,
    Object? registryAgentId = _Undefined,
    Object? expiresAt = _Undefined,
    Object? failureCode = _Undefined,
    Object? retryFromStep = _Undefined,
    Object? walletAuthJson = _Undefined,
    DateTime? updatedAt,
  }) {
    return StudioDeployRecord(
      id: id is int? ? id : this.id,
      draftId: draftId ?? this.draftId,
      owner: owner ?? this.owner,
      state: state ?? this.state,
      agentWallet: agentWallet ?? this.agentWallet,
      registrationUri: registrationUri ?? this.registrationUri,
      manifestJson: manifestJson is String? ? manifestJson : this.manifestJson,
      preparationId: preparationId is String?
          ? preparationId
          : this.preparationId,
      unsignedEnvelopeXdr: unsignedEnvelopeXdr is String?
          ? unsignedEnvelopeXdr
          : this.unsignedEnvelopeXdr,
      authorizationEntryXdr: authorizationEntryXdr is String?
          ? authorizationEntryXdr
          : this.authorizationEntryXdr,
      signatureExpirationLedger: signatureExpirationLedger is int?
          ? signatureExpirationLedger
          : this.signatureExpirationLedger,
      registrationHash: registrationHash is String?
          ? registrationHash
          : this.registrationHash,
      walletTxHash: walletTxHash is String? ? walletTxHash : this.walletTxHash,
      registryAgentId: registryAgentId is int?
          ? registryAgentId
          : this.registryAgentId,
      expiresAt: expiresAt is DateTime? ? expiresAt : this.expiresAt,
      failureCode: failureCode is String? ? failureCode : this.failureCode,
      retryFromStep: retryFromStep is int? ? retryFromStep : this.retryFromStep,
      walletAuthJson: walletAuthJson is String?
          ? walletAuthJson
          : this.walletAuthJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudioDeployRecordUpdateTable
    extends _is.UpdateTable<StudioDeployRecordTable> {
  StudioDeployRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> draftId(int value) => _is.ColumnValue(
    table.draftId,
    value,
  );

  _is.ColumnValue<String, String> owner(String value) => _is.ColumnValue(
    table.owner,
    value,
  );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<String, String> agentWallet(String value) => _is.ColumnValue(
    table.agentWallet,
    value,
  );

  _is.ColumnValue<String, String> registrationUri(String value) =>
      _is.ColumnValue(
        table.registrationUri,
        value,
      );

  _is.ColumnValue<String, String> manifestJson(String? value) =>
      _is.ColumnValue(
        table.manifestJson,
        value,
      );

  _is.ColumnValue<String, String> preparationId(String? value) =>
      _is.ColumnValue(
        table.preparationId,
        value,
      );

  _is.ColumnValue<String, String> unsignedEnvelopeXdr(String? value) =>
      _is.ColumnValue(
        table.unsignedEnvelopeXdr,
        value,
      );

  _is.ColumnValue<String, String> authorizationEntryXdr(String? value) =>
      _is.ColumnValue(
        table.authorizationEntryXdr,
        value,
      );

  _is.ColumnValue<int, int> signatureExpirationLedger(int? value) =>
      _is.ColumnValue(
        table.signatureExpirationLedger,
        value,
      );

  _is.ColumnValue<String, String> registrationHash(String? value) =>
      _is.ColumnValue(
        table.registrationHash,
        value,
      );

  _is.ColumnValue<String, String> walletTxHash(String? value) =>
      _is.ColumnValue(
        table.walletTxHash,
        value,
      );

  _is.ColumnValue<int, int> registryAgentId(int? value) => _is.ColumnValue(
    table.registryAgentId,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime? value) =>
      _is.ColumnValue(
        table.expiresAt,
        value,
      );

  _is.ColumnValue<String, String> failureCode(String? value) => _is.ColumnValue(
    table.failureCode,
    value,
  );

  _is.ColumnValue<int, int> retryFromStep(int? value) => _is.ColumnValue(
    table.retryFromStep,
    value,
  );

  _is.ColumnValue<String, String> walletAuthJson(String? value) =>
      _is.ColumnValue(
        table.walletAuthJson,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class StudioDeployRecordTable extends _is.Table<int?> {
  StudioDeployRecordTable({super.tableRelation})
    : super(tableName: 'studio_deploy') {
    updateTable = StudioDeployRecordUpdateTable(this);
    draftId = _is.ColumnInt(
      'draftId',
      this,
    );
    owner = _is.ColumnString(
      'owner',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    agentWallet = _is.ColumnString(
      'agentWallet',
      this,
    );
    registrationUri = _is.ColumnString(
      'registrationUri',
      this,
    );
    manifestJson = _is.ColumnString(
      'manifestJson',
      this,
    );
    preparationId = _is.ColumnString(
      'preparationId',
      this,
    );
    unsignedEnvelopeXdr = _is.ColumnString(
      'unsignedEnvelopeXdr',
      this,
    );
    authorizationEntryXdr = _is.ColumnString(
      'authorizationEntryXdr',
      this,
    );
    signatureExpirationLedger = _is.ColumnInt(
      'signatureExpirationLedger',
      this,
    );
    registrationHash = _is.ColumnString(
      'registrationHash',
      this,
    );
    walletTxHash = _is.ColumnString(
      'walletTxHash',
      this,
    );
    registryAgentId = _is.ColumnInt(
      'registryAgentId',
      this,
    );
    expiresAt = _is.ColumnDateTime(
      'expiresAt',
      this,
    );
    failureCode = _is.ColumnString(
      'failureCode',
      this,
    );
    retryFromStep = _is.ColumnInt(
      'retryFromStep',
      this,
    );
    walletAuthJson = _is.ColumnString(
      'walletAuthJson',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final StudioDeployRecordUpdateTable updateTable;

  late final _is.ColumnInt draftId;

  late final _is.ColumnString owner;

  late final _is.ColumnString state;

  late final _is.ColumnString agentWallet;

  late final _is.ColumnString registrationUri;

  /// Draft document that was hashed and registered. The prompt stays here.
  late final _is.ColumnString manifestJson;

  late final _is.ColumnString preparationId;

  late final _is.ColumnString unsignedEnvelopeXdr;

  late final _is.ColumnString authorizationEntryXdr;

  late final _is.ColumnInt signatureExpirationLedger;

  late final _is.ColumnString registrationHash;

  late final _is.ColumnString walletTxHash;

  late final _is.ColumnInt registryAgentId;

  late final _is.ColumnDateTime expiresAt;

  late final _is.ColumnString failureCode;

  late final _is.ColumnInt retryFromStep;

  /// JSON [WalletAuthDraft], enough to rebuild set_agent_wallet.
  late final _is.ColumnString walletAuthJson;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    draftId,
    owner,
    state,
    agentWallet,
    registrationUri,
    manifestJson,
    preparationId,
    unsignedEnvelopeXdr,
    authorizationEntryXdr,
    signatureExpirationLedger,
    registrationHash,
    walletTxHash,
    registryAgentId,
    expiresAt,
    failureCode,
    retryFromStep,
    walletAuthJson,
    updatedAt,
  ];
}

class StudioDeployRecordInclude extends _is.IncludeObject {
  StudioDeployRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => StudioDeployRecord.t;
}

class StudioDeployRecordIncludeList extends _is.IncludeList {
  StudioDeployRecordIncludeList._({
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StudioDeployRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => StudioDeployRecord.t;
}

class StudioDeployRecordRepository {
  const StudioDeployRecordRepository._();

  /// Returns a list of [StudioDeployRecord]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<StudioDeployRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioDeployRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDeployRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StudioDeployRecord>(
      where: where?.call(StudioDeployRecord.t),
      orderBy: orderBy?.call(StudioDeployRecord.t),
      orderByList: orderByList?.call(StudioDeployRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [StudioDeployRecord] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<StudioDeployRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<StudioDeployRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDeployRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StudioDeployRecord>(
      where: where?.call(StudioDeployRecord.t),
      orderBy: orderBy?.call(StudioDeployRecord.t),
      orderByList: orderByList?.call(StudioDeployRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StudioDeployRecord] by its [id] or null if no such row exists.
  Future<StudioDeployRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StudioDeployRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StudioDeployRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [StudioDeployRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDeployRecord>> insert(
    _is.DatabaseSession session,
    List<StudioDeployRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<StudioDeployRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [StudioDeployRecord] and returns the inserted row.
  ///
  /// The returned [StudioDeployRecord] will have its `id` field set.
  Future<StudioDeployRecord> insertRow(
    _is.DatabaseSession session,
    StudioDeployRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<StudioDeployRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [StudioDeployRecord]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [StudioDeployRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDeployRecord>> upsert(
    _is.DatabaseSession session,
    List<StudioDeployRecord> rows, {
    required _is.ColumnSelections<StudioDeployRecordTable> conflictColumns,
    _is.ColumnSelections<StudioDeployRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<StudioDeployRecord>(
      rows,
      conflictColumns: conflictColumns(StudioDeployRecord.t),
      updateColumns: updateColumns?.call(StudioDeployRecord.t),
      updateWhere: updateWhere?.call(StudioDeployRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [StudioDeployRecord] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [StudioDeployRecord] will have its `id` field set.
  Future<StudioDeployRecord?> upsertRow(
    _is.DatabaseSession session,
    StudioDeployRecord row, {
    required _is.ColumnSelections<StudioDeployRecordTable> conflictColumns,
    _is.ColumnSelections<StudioDeployRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<StudioDeployRecord>(
      row,
      conflictColumns: conflictColumns(StudioDeployRecord.t),
      updateColumns: updateColumns?.call(StudioDeployRecord.t),
      updateWhere: updateWhere?.call(StudioDeployRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [StudioDeployRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDeployRecord>> update(
    _is.DatabaseSession session,
    List<StudioDeployRecord> rows, {
    _is.ColumnSelections<StudioDeployRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<StudioDeployRecord>(
      rows,
      columns: columns?.call(StudioDeployRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [StudioDeployRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StudioDeployRecord> updateRow(
    _is.DatabaseSession session,
    StudioDeployRecord row, {
    _is.ColumnSelections<StudioDeployRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<StudioDeployRecord>(
      row,
      columns: columns?.call(StudioDeployRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StudioDeployRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StudioDeployRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<StudioDeployRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<StudioDeployRecord>(
      id,
      columnValues: columnValues(StudioDeployRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StudioDeployRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDeployRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StudioDeployRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<StudioDeployRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioDeployRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDeployRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<StudioDeployRecord>(
      columnValues: columnValues(StudioDeployRecord.t.updateTable),
      where: where(StudioDeployRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StudioDeployRecord.t),
      orderByList: orderByList?.call(StudioDeployRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [StudioDeployRecord]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDeployRecord>> delete(
    _is.DatabaseSession session,
    List<StudioDeployRecord> rows, {
    _is.OrderByBuilder<StudioDeployRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDeployRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<StudioDeployRecord>(
      rows,
      orderBy: orderBy?.call(StudioDeployRecord.t),
      orderByList: orderByList?.call(StudioDeployRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [StudioDeployRecord].
  Future<StudioDeployRecord> deleteRow(
    _is.DatabaseSession session,
    StudioDeployRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StudioDeployRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDeployRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StudioDeployRecordTable> where,
    _is.OrderByBuilder<StudioDeployRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDeployRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<StudioDeployRecord>(
      where: where(StudioDeployRecord.t),
      orderBy: orderBy?.call(StudioDeployRecord.t),
      orderByList: orderByList?.call(StudioDeployRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioDeployRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<StudioDeployRecord>(
      where: where?.call(StudioDeployRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StudioDeployRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StudioDeployRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StudioDeployRecord>(
      where: where(StudioDeployRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
