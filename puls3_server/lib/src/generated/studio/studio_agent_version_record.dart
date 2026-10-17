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

/// One published snapshot of a Studio agent. In-flight hires keep the
/// version they paid for. The prompt stays in this server-only row.
abstract class StudioAgentVersionRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  StudioAgentVersionRecord._({
    this.id,
    required this.registryAgentId,
    required this.version,
    required this.owner,
    required this.manifestJson,
    required this.updatedAt,
  });

  factory StudioAgentVersionRecord({
    int? id,
    required int registryAgentId,
    required int version,
    required String owner,
    required String manifestJson,
    required DateTime updatedAt,
  }) = _StudioAgentVersionRecordImpl;

  factory StudioAgentVersionRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return StudioAgentVersionRecord(
      id: jsonSerialization['id'] as int?,
      registryAgentId: jsonSerialization['registryAgentId'] as int,
      version: jsonSerialization['version'] as int,
      owner: jsonSerialization['owner'] as String,
      manifestJson: jsonSerialization['manifestJson'] as String,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = StudioAgentVersionRecordTable();

  static const db = StudioAgentVersionRecordRepository._();

  @override
  int? id;

  int registryAgentId;

  int version;

  String owner;

  String manifestJson;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [StudioAgentVersionRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  StudioAgentVersionRecord copyWith({
    int? id,
    int? registryAgentId,
    int? version,
    String? owner,
    String? manifestJson,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StudioAgentVersionRecord',
      if (id != null) 'id': id,
      'registryAgentId': registryAgentId,
      'version': version,
      'owner': owner,
      'manifestJson': manifestJson,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static StudioAgentVersionRecordInclude include() {
    return StudioAgentVersionRecordInclude._();
  }

  static StudioAgentVersionRecordIncludeList includeList({
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioAgentVersionRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioAgentVersionRecordTable>? orderByList,
    StudioAgentVersionRecordInclude? include,
  }) {
    return StudioAgentVersionRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StudioAgentVersionRecord.t),
      orderByList: orderByList?.call(StudioAgentVersionRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StudioAgentVersionRecordImpl extends StudioAgentVersionRecord {
  _StudioAgentVersionRecordImpl({
    int? id,
    required int registryAgentId,
    required int version,
    required String owner,
    required String manifestJson,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         registryAgentId: registryAgentId,
         version: version,
         owner: owner,
         manifestJson: manifestJson,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [StudioAgentVersionRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  StudioAgentVersionRecord copyWith({
    Object? id = _Undefined,
    int? registryAgentId,
    int? version,
    String? owner,
    String? manifestJson,
    DateTime? updatedAt,
  }) {
    return StudioAgentVersionRecord(
      id: id is int? ? id : this.id,
      registryAgentId: registryAgentId ?? this.registryAgentId,
      version: version ?? this.version,
      owner: owner ?? this.owner,
      manifestJson: manifestJson ?? this.manifestJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class StudioAgentVersionRecordUpdateTable
    extends _is.UpdateTable<StudioAgentVersionRecordTable> {
  StudioAgentVersionRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> registryAgentId(int value) => _is.ColumnValue(
    table.registryAgentId,
    value,
  );

  _is.ColumnValue<int, int> version(int value) => _is.ColumnValue(
    table.version,
    value,
  );

  _is.ColumnValue<String, String> owner(String value) => _is.ColumnValue(
    table.owner,
    value,
  );

  _is.ColumnValue<String, String> manifestJson(String value) => _is.ColumnValue(
    table.manifestJson,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class StudioAgentVersionRecordTable extends _is.Table<int?> {
  StudioAgentVersionRecordTable({super.tableRelation})
    : super(tableName: 'studio_agent_version') {
    updateTable = StudioAgentVersionRecordUpdateTable(this);
    registryAgentId = _is.ColumnInt(
      'registryAgentId',
      this,
    );
    version = _is.ColumnInt(
      'version',
      this,
    );
    owner = _is.ColumnString(
      'owner',
      this,
    );
    manifestJson = _is.ColumnString(
      'manifestJson',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final StudioAgentVersionRecordUpdateTable updateTable;

  late final _is.ColumnInt registryAgentId;

  late final _is.ColumnInt version;

  late final _is.ColumnString owner;

  late final _is.ColumnString manifestJson;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    registryAgentId,
    version,
    owner,
    manifestJson,
    updatedAt,
  ];
}

class StudioAgentVersionRecordInclude extends _is.IncludeObject {
  StudioAgentVersionRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => StudioAgentVersionRecord.t;
}

class StudioAgentVersionRecordIncludeList extends _is.IncludeList {
  StudioAgentVersionRecordIncludeList._({
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(StudioAgentVersionRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => StudioAgentVersionRecord.t;
}

class StudioAgentVersionRecordRepository {
  const StudioAgentVersionRecordRepository._();

  /// Returns a list of [StudioAgentVersionRecord]s matching the given query parameters.
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
  Future<List<StudioAgentVersionRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioAgentVersionRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioAgentVersionRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<StudioAgentVersionRecord>(
      where: where?.call(StudioAgentVersionRecord.t),
      orderBy: orderBy?.call(StudioAgentVersionRecord.t),
      orderByList: orderByList?.call(StudioAgentVersionRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [StudioAgentVersionRecord] matching the given query parameters.
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
  Future<StudioAgentVersionRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<StudioAgentVersionRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioAgentVersionRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<StudioAgentVersionRecord>(
      where: where?.call(StudioAgentVersionRecord.t),
      orderBy: orderBy?.call(StudioAgentVersionRecord.t),
      orderByList: orderByList?.call(StudioAgentVersionRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [StudioAgentVersionRecord] by its [id] or null if no such row exists.
  Future<StudioAgentVersionRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<StudioAgentVersionRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [StudioAgentVersionRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [StudioAgentVersionRecord]s will have their `id` fields set.
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
  Future<List<StudioAgentVersionRecord>> insert(
    _is.DatabaseSession session,
    List<StudioAgentVersionRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<StudioAgentVersionRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [StudioAgentVersionRecord] and returns the inserted row.
  ///
  /// The returned [StudioAgentVersionRecord] will have its `id` field set.
  Future<StudioAgentVersionRecord> insertRow(
    _is.DatabaseSession session,
    StudioAgentVersionRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<StudioAgentVersionRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [StudioAgentVersionRecord]s in the list and returns the resulting rows.
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
  /// The returned [StudioAgentVersionRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioAgentVersionRecord>> upsert(
    _is.DatabaseSession session,
    List<StudioAgentVersionRecord> rows, {
    required _is.ColumnSelections<StudioAgentVersionRecordTable>
    conflictColumns,
    _is.ColumnSelections<StudioAgentVersionRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<StudioAgentVersionRecord>(
      rows,
      conflictColumns: conflictColumns(StudioAgentVersionRecord.t),
      updateColumns: updateColumns?.call(StudioAgentVersionRecord.t),
      updateWhere: updateWhere?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [StudioAgentVersionRecord] and returns the resulting row.
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
  /// The returned [StudioAgentVersionRecord] will have its `id` field set.
  Future<StudioAgentVersionRecord?> upsertRow(
    _is.DatabaseSession session,
    StudioAgentVersionRecord row, {
    required _is.ColumnSelections<StudioAgentVersionRecordTable>
    conflictColumns,
    _is.ColumnSelections<StudioAgentVersionRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<StudioAgentVersionRecord>(
      row,
      conflictColumns: conflictColumns(StudioAgentVersionRecord.t),
      updateColumns: updateColumns?.call(StudioAgentVersionRecord.t),
      updateWhere: updateWhere?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [StudioAgentVersionRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioAgentVersionRecord>> update(
    _is.DatabaseSession session,
    List<StudioAgentVersionRecord> rows, {
    _is.ColumnSelections<StudioAgentVersionRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<StudioAgentVersionRecord>(
      rows,
      columns: columns?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [StudioAgentVersionRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<StudioAgentVersionRecord> updateRow(
    _is.DatabaseSession session,
    StudioAgentVersionRecord row, {
    _is.ColumnSelections<StudioAgentVersionRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<StudioAgentVersionRecord>(
      row,
      columns: columns?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [StudioAgentVersionRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<StudioAgentVersionRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<StudioAgentVersionRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<StudioAgentVersionRecord>(
      id,
      columnValues: columnValues(StudioAgentVersionRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [StudioAgentVersionRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<StudioAgentVersionRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<StudioAgentVersionRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<StudioAgentVersionRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<StudioAgentVersionRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioAgentVersionRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<StudioAgentVersionRecord>(
      columnValues: columnValues(StudioAgentVersionRecord.t.updateTable),
      where: where(StudioAgentVersionRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(StudioAgentVersionRecord.t),
      orderByList: orderByList?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [StudioAgentVersionRecord]s in the list and returns the deleted rows.
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
  Future<List<StudioAgentVersionRecord>> delete(
    _is.DatabaseSession session,
    List<StudioAgentVersionRecord> rows, {
    _is.OrderByBuilder<StudioAgentVersionRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioAgentVersionRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<StudioAgentVersionRecord>(
      rows,
      orderBy: orderBy?.call(StudioAgentVersionRecord.t),
      orderByList: orderByList?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [StudioAgentVersionRecord].
  Future<StudioAgentVersionRecord> deleteRow(
    _is.DatabaseSession session,
    StudioAgentVersionRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<StudioAgentVersionRecord>(
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
  Future<List<StudioAgentVersionRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StudioAgentVersionRecordTable> where,
    _is.OrderByBuilder<StudioAgentVersionRecordTable>? orderBy,
    _is.OrderByListBuilder<StudioAgentVersionRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<StudioAgentVersionRecord>(
      where: where(StudioAgentVersionRecord.t),
      orderBy: orderBy?.call(StudioAgentVersionRecord.t),
      orderByList: orderByList?.call(StudioAgentVersionRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<StudioAgentVersionRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<StudioAgentVersionRecord>(
      where: where?.call(StudioAgentVersionRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [StudioAgentVersionRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<StudioAgentVersionRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<StudioAgentVersionRecord>(
      where: where(StudioAgentVersionRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
