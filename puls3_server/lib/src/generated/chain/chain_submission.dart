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

/// Durable server-side record of one relay or server-signed submission.
/// Polled through the resource that owns it; the client sees only the
/// fields without `scope=serverOnly`. Serverpod requires serverOnly fields to
/// be nullable; ChainSubmissionStore always sets them.
abstract class ChainSubmission
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ChainSubmission._({
    this.id,
    this.preparationId,
    required this.purpose,
    required this.transaction,
    required this.state,
    this.errorCode,
    this.explorerUrl,
    required this.updatedAt,
    this.hireId,
    this.signedEnvelopeXdr,
    this.validUntil,
    this.lastSentAt,
    int? sendAttempts,
    this.createdAt,
    this.lastCheckedAt,
  }) : sendAttempts = sendAttempts ?? 0;

  factory ChainSubmission({
    int? id,
    String? preparationId,
    required String purpose,
    required String transaction,
    required String state,
    String? errorCode,
    String? explorerUrl,
    required DateTime updatedAt,
    int? hireId,
    String? signedEnvelopeXdr,
    DateTime? validUntil,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? createdAt,
    DateTime? lastCheckedAt,
  }) = _ChainSubmissionImpl;

  factory ChainSubmission.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChainSubmission(
      id: jsonSerialization['id'] as int?,
      preparationId: jsonSerialization['preparationId'] as String?,
      purpose: jsonSerialization['purpose'] as String,
      transaction: jsonSerialization['transaction'] as String,
      state: jsonSerialization['state'] as String,
      errorCode: jsonSerialization['errorCode'] as String?,
      explorerUrl: jsonSerialization['explorerUrl'] as String?,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      hireId: jsonSerialization['hireId'] as int?,
      signedEnvelopeXdr: jsonSerialization['signedEnvelopeXdr'] as String?,
      validUntil: jsonSerialization['validUntil'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['validUntil']),
      lastSentAt: jsonSerialization['lastSentAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastSentAt']),
      sendAttempts: jsonSerialization['sendAttempts'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
      lastCheckedAt: jsonSerialization['lastCheckedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastCheckedAt'],
            ),
    );
  }

  static final t = ChainSubmissionTable();

  static const db = ChainSubmissionRepository._();

  @override
  int? id;

  /// The PreparedTransaction this submission came from. Null for
  /// server-signed purposes (submit, release, claimRefund).
  String? preparationId;

  /// One of registerFull, setAgentWallet, createJob, fund, complete, reject,
  /// giveFeedback (wallet-signed), or submit, release, claimRefund
  /// (server-signed).
  String purpose;

  /// Domain TransactionHash of the one envelope this record ever sends,
  /// persisted before it is submitted.
  String transaction;

  /// One of submitted, confirmed, failed.
  String state;

  /// Puls3ApiException code when state is failed, for example JobMismatch.
  /// Chain outcomes are reported here, never thrown by submit methods.
  String? errorCode;

  String? explorerUrl;

  DateTime updatedAt;

  /// The hire this submission belongs to, when it has one.
  int? hireId;

  /// The signed envelope in base64 XDR; resent unchanged when needed.
  String? signedEnvelopeXdr;

  /// End of the envelope time bounds; after it the submission is expired.
  DateTime? validUntil;

  /// Last send of the envelope; paces resends, never the tracker order.
  DateTime? lastSentAt;

  int? sendAttempts;

  DateTime? createdAt;

  /// Last time the tracker looked at a submitted record; createdAt on
  /// insert. The tracker lists the least recently checked records first.
  DateTime? lastCheckedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ChainSubmission]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ChainSubmission copyWith({
    int? id,
    String? preparationId,
    String? purpose,
    String? transaction,
    String? state,
    String? errorCode,
    String? explorerUrl,
    DateTime? updatedAt,
    int? hireId,
    String? signedEnvelopeXdr,
    DateTime? validUntil,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? createdAt,
    DateTime? lastCheckedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChainSubmission',
      if (id != null) 'id': id,
      if (preparationId != null) 'preparationId': preparationId,
      'purpose': purpose,
      'transaction': transaction,
      'state': state,
      if (errorCode != null) 'errorCode': errorCode,
      if (explorerUrl != null) 'explorerUrl': explorerUrl,
      'updatedAt': updatedAt.toJson(),
      if (hireId != null) 'hireId': hireId,
      if (signedEnvelopeXdr != null) 'signedEnvelopeXdr': signedEnvelopeXdr,
      if (validUntil != null) 'validUntil': validUntil?.toJson(),
      if (lastSentAt != null) 'lastSentAt': lastSentAt?.toJson(),
      if (sendAttempts != null) 'sendAttempts': sendAttempts,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
      if (lastCheckedAt != null) 'lastCheckedAt': lastCheckedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChainSubmission',
      if (id != null) 'id': id,
      if (preparationId != null) 'preparationId': preparationId,
      'purpose': purpose,
      'transaction': transaction,
      'state': state,
      if (errorCode != null) 'errorCode': errorCode,
      if (explorerUrl != null) 'explorerUrl': explorerUrl,
      'updatedAt': updatedAt.toJson(),
    };
  }

  static ChainSubmissionInclude include() {
    return ChainSubmissionInclude._();
  }

  static ChainSubmissionIncludeList includeList({
    _is.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _is.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    ChainSubmissionInclude? include,
  }) {
    return ChainSubmissionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChainSubmissionImpl extends ChainSubmission {
  _ChainSubmissionImpl({
    int? id,
    String? preparationId,
    required String purpose,
    required String transaction,
    required String state,
    String? errorCode,
    String? explorerUrl,
    required DateTime updatedAt,
    int? hireId,
    String? signedEnvelopeXdr,
    DateTime? validUntil,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? createdAt,
    DateTime? lastCheckedAt,
  }) : super._(
         id: id,
         preparationId: preparationId,
         purpose: purpose,
         transaction: transaction,
         state: state,
         errorCode: errorCode,
         explorerUrl: explorerUrl,
         updatedAt: updatedAt,
         hireId: hireId,
         signedEnvelopeXdr: signedEnvelopeXdr,
         validUntil: validUntil,
         lastSentAt: lastSentAt,
         sendAttempts: sendAttempts,
         createdAt: createdAt,
         lastCheckedAt: lastCheckedAt,
       );

  /// Returns a shallow copy of this [ChainSubmission]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ChainSubmission copyWith({
    Object? id = _Undefined,
    Object? preparationId = _Undefined,
    String? purpose,
    String? transaction,
    String? state,
    Object? errorCode = _Undefined,
    Object? explorerUrl = _Undefined,
    DateTime? updatedAt,
    Object? hireId = _Undefined,
    Object? signedEnvelopeXdr = _Undefined,
    Object? validUntil = _Undefined,
    Object? lastSentAt = _Undefined,
    Object? sendAttempts = _Undefined,
    Object? createdAt = _Undefined,
    Object? lastCheckedAt = _Undefined,
  }) {
    return ChainSubmission(
      id: id is int? ? id : this.id,
      preparationId: preparationId is String?
          ? preparationId
          : this.preparationId,
      purpose: purpose ?? this.purpose,
      transaction: transaction ?? this.transaction,
      state: state ?? this.state,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      explorerUrl: explorerUrl is String? ? explorerUrl : this.explorerUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      hireId: hireId is int? ? hireId : this.hireId,
      signedEnvelopeXdr: signedEnvelopeXdr is String?
          ? signedEnvelopeXdr
          : this.signedEnvelopeXdr,
      validUntil: validUntil is DateTime? ? validUntil : this.validUntil,
      lastSentAt: lastSentAt is DateTime? ? lastSentAt : this.lastSentAt,
      sendAttempts: sendAttempts is int? ? sendAttempts : this.sendAttempts,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
      lastCheckedAt: lastCheckedAt is DateTime?
          ? lastCheckedAt
          : this.lastCheckedAt,
    );
  }
}

class ChainSubmissionUpdateTable extends _is.UpdateTable<ChainSubmissionTable> {
  ChainSubmissionUpdateTable(super.table);

  _is.ColumnValue<String, String> preparationId(String? value) =>
      _is.ColumnValue(
        table.preparationId,
        value,
      );

  _is.ColumnValue<String, String> purpose(String value) => _is.ColumnValue(
    table.purpose,
    value,
  );

  _is.ColumnValue<String, String> transaction(String value) => _is.ColumnValue(
    table.transaction,
    value,
  );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<String, String> errorCode(String? value) => _is.ColumnValue(
    table.errorCode,
    value,
  );

  _is.ColumnValue<String, String> explorerUrl(String? value) => _is.ColumnValue(
    table.explorerUrl,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );

  _is.ColumnValue<int, int> hireId(int? value) => _is.ColumnValue(
    table.hireId,
    value,
  );

  _is.ColumnValue<String, String> signedEnvelopeXdr(String? value) =>
      _is.ColumnValue(
        table.signedEnvelopeXdr,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> validUntil(DateTime? value) =>
      _is.ColumnValue(
        table.validUntil,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastSentAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastSentAt,
        value,
      );

  _is.ColumnValue<int, int> sendAttempts(int? value) => _is.ColumnValue(
    table.sendAttempts,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime? value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastCheckedAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastCheckedAt,
        value,
      );
}

class ChainSubmissionTable extends _is.Table<int?> {
  ChainSubmissionTable({super.tableRelation})
    : super(tableName: 'chain_submission') {
    updateTable = ChainSubmissionUpdateTable(this);
    preparationId = _is.ColumnString(
      'preparationId',
      this,
    );
    purpose = _is.ColumnString(
      'purpose',
      this,
    );
    transaction = _is.ColumnString(
      'transaction',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    errorCode = _is.ColumnString(
      'errorCode',
      this,
    );
    explorerUrl = _is.ColumnString(
      'explorerUrl',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
    hireId = _is.ColumnInt(
      'hireId',
      this,
    );
    signedEnvelopeXdr = _is.ColumnString(
      'signedEnvelopeXdr',
      this,
    );
    validUntil = _is.ColumnDateTime(
      'validUntil',
      this,
    );
    lastSentAt = _is.ColumnDateTime(
      'lastSentAt',
      this,
    );
    sendAttempts = _is.ColumnInt(
      'sendAttempts',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    lastCheckedAt = _is.ColumnDateTime(
      'lastCheckedAt',
      this,
    );
  }

  late final ChainSubmissionUpdateTable updateTable;

  /// The PreparedTransaction this submission came from. Null for
  /// server-signed purposes (submit, release, claimRefund).
  late final _is.ColumnString preparationId;

  /// One of registerFull, setAgentWallet, createJob, fund, complete, reject,
  /// giveFeedback (wallet-signed), or submit, release, claimRefund
  /// (server-signed).
  late final _is.ColumnString purpose;

  /// Domain TransactionHash of the one envelope this record ever sends,
  /// persisted before it is submitted.
  late final _is.ColumnString transaction;

  /// One of submitted, confirmed, failed.
  late final _is.ColumnString state;

  /// Puls3ApiException code when state is failed, for example JobMismatch.
  /// Chain outcomes are reported here, never thrown by submit methods.
  late final _is.ColumnString errorCode;

  late final _is.ColumnString explorerUrl;

  late final _is.ColumnDateTime updatedAt;

  /// The hire this submission belongs to, when it has one.
  late final _is.ColumnInt hireId;

  /// The signed envelope in base64 XDR; resent unchanged when needed.
  late final _is.ColumnString signedEnvelopeXdr;

  /// End of the envelope time bounds; after it the submission is expired.
  late final _is.ColumnDateTime validUntil;

  /// Last send of the envelope; paces resends, never the tracker order.
  late final _is.ColumnDateTime lastSentAt;

  late final _is.ColumnInt sendAttempts;

  late final _is.ColumnDateTime createdAt;

  /// Last time the tracker looked at a submitted record; createdAt on
  /// insert. The tracker lists the least recently checked records first.
  late final _is.ColumnDateTime lastCheckedAt;

  @override
  List<_is.Column> get columns => [
    id,
    preparationId,
    purpose,
    transaction,
    state,
    errorCode,
    explorerUrl,
    updatedAt,
    hireId,
    signedEnvelopeXdr,
    validUntil,
    lastSentAt,
    sendAttempts,
    createdAt,
    lastCheckedAt,
  ];
}

class ChainSubmissionInclude extends _is.IncludeObject {
  ChainSubmissionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ChainSubmission.t;
}

class ChainSubmissionIncludeList extends _is.IncludeList {
  ChainSubmissionIncludeList._({
    _is.WhereExpressionBuilder<ChainSubmissionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ChainSubmission.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ChainSubmission.t;
}

class ChainSubmissionRepository {
  const ChainSubmissionRepository._();

  /// Returns a list of [ChainSubmission]s matching the given query parameters.
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
  Future<List<ChainSubmission>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _is.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ChainSubmission>(
      where: where?.call(ChainSubmission.t),
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ChainSubmission] matching the given query parameters.
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
  Future<ChainSubmission?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? offset,
    _is.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _is.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ChainSubmission>(
      where: where?.call(ChainSubmission.t),
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ChainSubmission] by its [id] or null if no such row exists.
  Future<ChainSubmission?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ChainSubmission>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ChainSubmission]s in the list and returns the inserted rows.
  ///
  /// The returned [ChainSubmission]s will have their `id` fields set.
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
  Future<List<ChainSubmission>> insert(
    _is.DatabaseSession session,
    List<ChainSubmission> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ChainSubmission>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ChainSubmission] and returns the inserted row.
  ///
  /// The returned [ChainSubmission] will have its `id` field set.
  Future<ChainSubmission> insertRow(
    _is.DatabaseSession session,
    ChainSubmission row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ChainSubmission>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ChainSubmission]s in the list and returns the resulting rows.
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
  /// The returned [ChainSubmission]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChainSubmission>> upsert(
    _is.DatabaseSession session,
    List<ChainSubmission> rows, {
    required _is.ColumnSelections<ChainSubmissionTable> conflictColumns,
    _is.ColumnSelections<ChainSubmissionTable>? updateColumns,
    _is.WhereExpressionBuilder<ChainSubmissionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ChainSubmission>(
      rows,
      conflictColumns: conflictColumns(ChainSubmission.t),
      updateColumns: updateColumns?.call(ChainSubmission.t),
      updateWhere: updateWhere?.call(ChainSubmission.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ChainSubmission] and returns the resulting row.
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
  /// The returned [ChainSubmission] will have its `id` field set.
  Future<ChainSubmission?> upsertRow(
    _is.DatabaseSession session,
    ChainSubmission row, {
    required _is.ColumnSelections<ChainSubmissionTable> conflictColumns,
    _is.ColumnSelections<ChainSubmissionTable>? updateColumns,
    _is.WhereExpressionBuilder<ChainSubmissionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ChainSubmission>(
      row,
      conflictColumns: conflictColumns(ChainSubmission.t),
      updateColumns: updateColumns?.call(ChainSubmission.t),
      updateWhere: updateWhere?.call(ChainSubmission.t),
      transaction: transaction,
    );
  }

  /// Updates all [ChainSubmission]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChainSubmission>> update(
    _is.DatabaseSession session,
    List<ChainSubmission> rows, {
    _is.ColumnSelections<ChainSubmissionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ChainSubmission>(
      rows,
      columns: columns?.call(ChainSubmission.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ChainSubmission]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ChainSubmission> updateRow(
    _is.DatabaseSession session,
    ChainSubmission row, {
    _is.ColumnSelections<ChainSubmissionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ChainSubmission>(
      row,
      columns: columns?.call(ChainSubmission.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChainSubmission] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ChainSubmission?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ChainSubmissionUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ChainSubmission>(
      id,
      columnValues: columnValues(ChainSubmission.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ChainSubmission]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ChainSubmission>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ChainSubmissionUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<ChainSubmissionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _is.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ChainSubmission>(
      columnValues: columnValues(ChainSubmission.t.updateTable),
      where: where(ChainSubmission.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ChainSubmission]s in the list and returns the deleted rows.
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
  Future<List<ChainSubmission>> delete(
    _is.DatabaseSession session,
    List<ChainSubmission> rows, {
    _is.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _is.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ChainSubmission>(
      rows,
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ChainSubmission].
  Future<ChainSubmission> deleteRow(
    _is.DatabaseSession session,
    ChainSubmission row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ChainSubmission>(
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
  Future<List<ChainSubmission>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ChainSubmissionTable> where,
    _is.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _is.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ChainSubmission>(
      where: where(ChainSubmission.t),
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ChainSubmission>(
      where: where?.call(ChainSubmission.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ChainSubmission] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ChainSubmissionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ChainSubmission>(
      where: where(ChainSubmission.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
