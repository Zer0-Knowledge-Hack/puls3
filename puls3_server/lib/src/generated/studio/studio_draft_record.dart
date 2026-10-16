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

/// Server-only row for a Studio draft. The prompt lives in [manifestJson]
/// and is never returned to a wallet that does not own the row.
abstract class StudioDraftRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  StudioDraftRecord._({
    this.id,
    required this.owner,
    required this.revision,
    required this.manifestJson,
    required this.deployState,
    this.liveVersion,
    this.agentId,
    this.retryFromStep,
    required this.updatedAt,
  });

  factory StudioDraftRecord({
    int? id,
    required String owner,
    required int revision,
    required String manifestJson,
    required String deployState,
    int? liveVersion,
    String? agentId,
    int? retryFromStep,
    required DateTime updatedAt,
  }) = _StudioDraftRecordImpl;

  factory StudioDraftRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return StudioDraftRecord(
      id: jsonSerialization['id'] as int?,
      owner: jsonSerialization['owner'] as String,
      revision: jsonSerialization['revision'] as int,
      manifestJson: jsonSerialization['manifestJson'] as String,
      deployState: jsonSerialization['deployState'] as String,
      liveVersion: jsonSerialization['liveVersion'] as int?,
      agentId: jsonSerialization['agentId'] as String?,
      retryFromStep: jsonSerialization['retryFromStep'] as int?,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = StudioDraftRecordTable();

  static const db = StudioDraftRecordRepository._();

  @override
  int? id;

  /// Session wallet that owns the draft, a G… address.
  String owner;

  /// Starts at 1 and increases on every successful save.
  int revision;

  /// Domain wire JSON of the draft (`AgentManifestDraft.toJson`).
  String manifestJson;

  /// draft, deploying, failed, or live.
  String deployState;

  int? liveVersion;

  /// Catalog id once the agent is listed.
  String? agentId;

  int? retryFromStep;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [StudioDraftRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StudioDraftRecord copyWith({
    int? id,
    String? owner,
    int? revision,
    String? manifestJson,
    String? deployState,
    int? liveVersion,
    String? agentId,
    int? retryFromStep,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StudioDraftRecord',
      if (id != null) 'id': id,
      'owner': owner,
      'revision': revision,
      'manifestJson': manifestJson,
      'deployState': deployState,
      if (liveVersion != null) 'liveVersion': liveVersion,
      if (agentId != null) 'agentId': agentId,
      if (retryFromStep != null) 'retryFromStep': retryFromStep,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static StudioDraftRecordInclude include() {
    return StudioDraftRecordInclude._();
  }

  static StudioDraftRecordIncludeList includeList({
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioDraftRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDraftRecordTable>? orderByList,
    StudioDraftRecordInclude? include,
  }) {
    return StudioDraftRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StudioDraftRecord.t),
      orderByList: orderByList?.call(StudioDraftRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StudioDraftRecordImpl extends StudioDraftRecord {
  _StudioDraftRecordImpl({
    int? id,
    required String owner,
    required int revision,
    required String manifestJson,
    required String deployState,
    int? liveVersion,
    String? agentId,
    int? retryFromStep,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         owner: owner,
         revision: revision,
         manifestJson: manifestJson,
         deployState: deployState,
         liveVersion: liveVersion,
         agentId: agentId,
         retryFromStep: retryFromStep,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [StudioDraftRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StudioDraftRecord copyWith({
    Object? id = _Undefined,
    String? owner,
    int? revision,
    String? manifestJson,
    String? deployState,
    Object? liveVersion = _Undefined,
    Object? agentId = _Undefined,
    Object? retryFromStep = _Undefined,
    DateTime? updatedAt,
  }) {
    return StudioDraftRecord(
      id: id is int? ? id : this.id,
      owner: owner ?? this.owner,
      revision: revision ?? this.revision,
      manifestJson: manifestJson ?? this.manifestJson,
      deployState: deployState ?? this.deployState,
      liveVersion: liveVersion is int? ? liveVersion : this.liveVersion,
      agentId: agentId is String? ? agentId : this.agentId,
      retryFromStep: retryFromStep is int? ? retryFromStep : this.retryFromStep,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudioDraftRecordUpdateTable
    extends _is.UpdateTable<StudioDraftRecordTable> {
  StudioDraftRecordUpdateTable(super.table);

  _is.ColumnValue<String, String> owner(String value) => _is.ColumnValue(
    table.owner,
    value,
  );

  _is.ColumnValue<int, int> revision(int value) => _is.ColumnValue(
    table.revision,
    value,
  );

  _is.ColumnValue<String, String> manifestJson(String value) => _is.ColumnValue(
    table.manifestJson,
    value,
  );

  _is.ColumnValue<String, String> deployState(String value) => _is.ColumnValue(
    table.deployState,
    value,
  );

  _is.ColumnValue<int, int> liveVersion(int? value) => _is.ColumnValue(
    table.liveVersion,
    value,
  );

  _is.ColumnValue<String, String> agentId(String? value) => _is.ColumnValue(
    table.agentId,
    value,
  );

  _is.ColumnValue<int, int> retryFromStep(int? value) => _is.ColumnValue(
    table.retryFromStep,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class StudioDraftRecordTable extends _is.Table<int?> {
  StudioDraftRecordTable({super.tableRelation})
    : super(tableName: 'studio_draft') {
    updateTable = StudioDraftRecordUpdateTable(this);
    owner = _is.ColumnString(
      'owner',
      this,
    );
    revision = _is.ColumnInt(
      'revision',
      this,
    );
    manifestJson = _is.ColumnString(
      'manifestJson',
      this,
    );
    deployState = _is.ColumnString(
      'deployState',
      this,
    );
    liveVersion = _is.ColumnInt(
      'liveVersion',
      this,
    );
    agentId = _is.ColumnString(
      'agentId',
      this,
    );
    retryFromStep = _is.ColumnInt(
      'retryFromStep',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final StudioDraftRecordUpdateTable updateTable;

  /// Session wallet that owns the draft, a G… address.
  late final _is.ColumnString owner;

  /// Starts at 1 and increases on every successful save.
  late final _is.ColumnInt revision;

  /// Domain wire JSON of the draft (`AgentManifestDraft.toJson`).
  late final _is.ColumnString manifestJson;

  /// draft, deploying, failed, or live.
  late final _is.ColumnString deployState;

  late final _is.ColumnInt liveVersion;

  /// Catalog id once the agent is listed.
  late final _is.ColumnString agentId;

  late final _is.ColumnInt retryFromStep;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    owner,
    revision,
    manifestJson,
    deployState,
    liveVersion,
    agentId,
    retryFromStep,
    updatedAt,
  ];
}

class StudioDraftRecordInclude extends _is.IncludeObject {
  StudioDraftRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => StudioDraftRecord.t;
}

class StudioDraftRecordIncludeList extends _is.IncludeList {
  StudioDraftRecordIncludeList._({
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StudioDraftRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => StudioDraftRecord.t;
}

class StudioDraftRecordRepository {
  const StudioDraftRecordRepository._();

  /// Returns a list of [StudioDraftRecord]s matching the given query parameters.
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
  Future<List<StudioDraftRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioDraftRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDraftRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StudioDraftRecord>(
      where: where?.call(StudioDraftRecord.t),
      orderBy: orderBy?.call(StudioDraftRecord.t),
      orderByList: orderByList?.call(StudioDraftRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [StudioDraftRecord] matching the given query parameters.
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
  Future<StudioDraftRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<StudioDraftRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDraftRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StudioDraftRecord>(
      where: where?.call(StudioDraftRecord.t),
      orderBy: orderBy?.call(StudioDraftRecord.t),
      orderByList: orderByList?.call(StudioDraftRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StudioDraftRecord] by its [id] or null if no such row exists.
  Future<StudioDraftRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StudioDraftRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StudioDraftRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [StudioDraftRecord]s will have their `id` fields set.
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
  Future<List<StudioDraftRecord>> insert(
    _is.DatabaseSession session,
    List<StudioDraftRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<StudioDraftRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [StudioDraftRecord] and returns the inserted row.
  ///
  /// The returned [StudioDraftRecord] will have its `id` field set.
  Future<StudioDraftRecord> insertRow(
    _is.DatabaseSession session,
    StudioDraftRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<StudioDraftRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [StudioDraftRecord]s in the list and returns the resulting rows.
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
  /// The returned [StudioDraftRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDraftRecord>> upsert(
    _is.DatabaseSession session,
    List<StudioDraftRecord> rows, {
    required _is.ColumnSelections<StudioDraftRecordTable> conflictColumns,
    _is.ColumnSelections<StudioDraftRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<StudioDraftRecord>(
      rows,
      conflictColumns: conflictColumns(StudioDraftRecord.t),
      updateColumns: updateColumns?.call(StudioDraftRecord.t),
      updateWhere: updateWhere?.call(StudioDraftRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [StudioDraftRecord] and returns the resulting row.
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
  /// The returned [StudioDraftRecord] will have its `id` field set.
  Future<StudioDraftRecord?> upsertRow(
    _is.DatabaseSession session,
    StudioDraftRecord row, {
    required _is.ColumnSelections<StudioDraftRecordTable> conflictColumns,
    _is.ColumnSelections<StudioDraftRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<StudioDraftRecord>(
      row,
      conflictColumns: conflictColumns(StudioDraftRecord.t),
      updateColumns: updateColumns?.call(StudioDraftRecord.t),
      updateWhere: updateWhere?.call(StudioDraftRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [StudioDraftRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDraftRecord>> update(
    _is.DatabaseSession session,
    List<StudioDraftRecord> rows, {
    _is.ColumnSelections<StudioDraftRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<StudioDraftRecord>(
      rows,
      columns: columns?.call(StudioDraftRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [StudioDraftRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StudioDraftRecord> updateRow(
    _is.DatabaseSession session,
    StudioDraftRecord row, {
    _is.ColumnSelections<StudioDraftRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<StudioDraftRecord>(
      row,
      columns: columns?.call(StudioDraftRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StudioDraftRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StudioDraftRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<StudioDraftRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<StudioDraftRecord>(
      id,
      columnValues: columnValues(StudioDraftRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StudioDraftRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioDraftRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StudioDraftRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<StudioDraftRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioDraftRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDraftRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<StudioDraftRecord>(
      columnValues: columnValues(StudioDraftRecord.t.updateTable),
      where: where(StudioDraftRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StudioDraftRecord.t),
      orderByList: orderByList?.call(StudioDraftRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [StudioDraftRecord]s in the list and returns the deleted rows.
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
  Future<List<StudioDraftRecord>> delete(
    _is.DatabaseSession session,
    List<StudioDraftRecord> rows, {
    _is.OrderByBuilder<StudioDraftRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDraftRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<StudioDraftRecord>(
      rows,
      orderBy: orderBy?.call(StudioDraftRecord.t),
      orderByList: orderByList?.call(StudioDraftRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [StudioDraftRecord].
  Future<StudioDraftRecord> deleteRow(
    _is.DatabaseSession session,
    StudioDraftRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StudioDraftRecord>(
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
  Future<List<StudioDraftRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StudioDraftRecordTable> where,
    _is.OrderByBuilder<StudioDraftRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioDraftRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<StudioDraftRecord>(
      where: where(StudioDraftRecord.t),
      orderBy: orderBy?.call(StudioDraftRecord.t),
      orderByList: orderByList?.call(StudioDraftRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioDraftRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<StudioDraftRecord>(
      where: where?.call(StudioDraftRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StudioDraftRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StudioDraftRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StudioDraftRecord>(
      where: where(StudioDraftRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
