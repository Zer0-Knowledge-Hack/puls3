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

/// The agent run of one funded hire (#20). Created as queued in the same
/// transaction that records the hire's payment, so every funded hire gets
/// exactly one run. State changes are conditional updates, so two runners
/// never run the same hire.
abstract class HireRunRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  HireRunRecord._({
    this.id,
    required this.hireId,
    required this.state,
    required this.queuedAt,
    this.startedAt,
    this.finishedAt,
    this.result,
    this.failureReason,
  });

  factory HireRunRecord({
    int? id,
    required int hireId,
    required String state,
    required DateTime queuedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? result,
    String? failureReason,
  }) = _HireRunRecordImpl;

  factory HireRunRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireRunRecord(
      id: jsonSerialization['id'] as int?,
      hireId: jsonSerialization['hireId'] as int,
      state: jsonSerialization['state'] as String,
      queuedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['queuedAt'],
      ),
      startedAt: jsonSerialization['startedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['startedAt']),
      finishedAt: jsonSerialization['finishedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['finishedAt']),
      result: jsonSerialization['result'] as String?,
      failureReason: jsonSerialization['failureReason'] as String?,
    );
  }

  static final t = HireRunRecordTable();

  static const db = HireRunRecordRepository._();

  @override
  int? id;

  int hireId;

  /// queued, running, succeeded or failed.
  String state;

  DateTime queuedAt;

  DateTime? startedAt;

  DateTime? finishedAt;

  /// The agent's output, set when the run succeeded.
  String? result;

  /// A safe RuntimeFailure code (for example timeout), set when it failed.
  String? failureReason;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [HireRunRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  HireRunRecord copyWith({
    int? id,
    int? hireId,
    String? state,
    DateTime? queuedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? result,
    String? failureReason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireRunRecord',
      if (id != null) 'id': id,
      'hireId': hireId,
      'state': state,
      'queuedAt': queuedAt.toJson(),
      if (startedAt != null) 'startedAt': startedAt?.toJson(),
      if (finishedAt != null) 'finishedAt': finishedAt?.toJson(),
      if (result != null) 'result': result,
      if (failureReason != null) 'failureReason': failureReason,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static HireRunRecordInclude include() {
    return HireRunRecordInclude._();
  }

  static HireRunRecordIncludeList includeList({
    _is.WhereExpressionBuilder<HireRunRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireRunRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRunRecordTable>? orderByList,
    HireRunRecordInclude? include,
  }) {
    return HireRunRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireRunRecord.t),
      orderByList: orderByList?.call(HireRunRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireRunRecordImpl extends HireRunRecord {
  _HireRunRecordImpl({
    int? id,
    required int hireId,
    required String state,
    required DateTime queuedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? result,
    String? failureReason,
  }) : super._(
         id: id,
         hireId: hireId,
         state: state,
         queuedAt: queuedAt,
         startedAt: startedAt,
         finishedAt: finishedAt,
         result: result,
         failureReason: failureReason,
       );

  /// Returns a shallow copy of this [HireRunRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  HireRunRecord copyWith({
    Object? id = _Undefined,
    int? hireId,
    String? state,
    DateTime? queuedAt,
    Object? startedAt = _Undefined,
    Object? finishedAt = _Undefined,
    Object? result = _Undefined,
    Object? failureReason = _Undefined,
  }) {
    return HireRunRecord(
      id: id is int? ? id : this.id,
      hireId: hireId ?? this.hireId,
      state: state ?? this.state,
      queuedAt: queuedAt ?? this.queuedAt,
      startedAt: startedAt is DateTime? ? startedAt : this.startedAt,
      finishedAt: finishedAt is DateTime? ? finishedAt : this.finishedAt,
      result: result is String? ? result : this.result,
      failureReason: failureReason is String?
          ? failureReason
          : this.failureReason,
    );
  }
}

class HireRunRecordUpdateTable extends _is.UpdateTable<HireRunRecordTable> {
  HireRunRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> hireId(int value) => _is.ColumnValue(
    table.hireId,
    value,
  );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> queuedAt(DateTime value) =>
      _is.ColumnValue(
        table.queuedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> startedAt(DateTime? value) =>
      _is.ColumnValue(
        table.startedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> finishedAt(DateTime? value) =>
      _is.ColumnValue(
        table.finishedAt,
        value,
      );

  _is.ColumnValue<String, String> result(String? value) => _is.ColumnValue(
    table.result,
    value,
  );

  _is.ColumnValue<String, String> failureReason(String? value) =>
      _is.ColumnValue(
        table.failureReason,
        value,
      );
}

class HireRunRecordTable extends _is.Table<int?> {
  HireRunRecordTable({super.tableRelation}) : super(tableName: 'hire_run') {
    updateTable = HireRunRecordUpdateTable(this);
    hireId = _is.ColumnInt(
      'hireId',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    queuedAt = _is.ColumnDateTime(
      'queuedAt',
      this,
    );
    startedAt = _is.ColumnDateTime(
      'startedAt',
      this,
    );
    finishedAt = _is.ColumnDateTime(
      'finishedAt',
      this,
    );
    result = _is.ColumnString(
      'result',
      this,
    );
    failureReason = _is.ColumnString(
      'failureReason',
      this,
    );
  }

  late final HireRunRecordUpdateTable updateTable;

  late final _is.ColumnInt hireId;

  /// queued, running, succeeded or failed.
  late final _is.ColumnString state;

  late final _is.ColumnDateTime queuedAt;

  late final _is.ColumnDateTime startedAt;

  late final _is.ColumnDateTime finishedAt;

  /// The agent's output, set when the run succeeded.
  late final _is.ColumnString result;

  /// A safe RuntimeFailure code (for example timeout), set when it failed.
  late final _is.ColumnString failureReason;

  @override
  List<_is.Column> get columns => [
    id,
    hireId,
    state,
    queuedAt,
    startedAt,
    finishedAt,
    result,
    failureReason,
  ];
}

class HireRunRecordInclude extends _is.IncludeObject {
  HireRunRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => HireRunRecord.t;
}

class HireRunRecordIncludeList extends _is.IncludeList {
  HireRunRecordIncludeList._({
    _is.WhereExpressionBuilder<HireRunRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HireRunRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => HireRunRecord.t;
}

class HireRunRecordRepository {
  const HireRunRecordRepository._();

  /// Returns a list of [HireRunRecord]s matching the given query parameters.
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
  Future<List<HireRunRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireRunRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireRunRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRunRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HireRunRecord>(
      where: where?.call(HireRunRecord.t),
      orderBy: orderBy?.call(HireRunRecord.t),
      orderByList: orderByList?.call(HireRunRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [HireRunRecord] matching the given query parameters.
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
  Future<HireRunRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireRunRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<HireRunRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRunRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HireRunRecord>(
      where: where?.call(HireRunRecord.t),
      orderBy: orderBy?.call(HireRunRecord.t),
      orderByList: orderByList?.call(HireRunRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HireRunRecord] by its [id] or null if no such row exists.
  Future<HireRunRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<HireRunRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [HireRunRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [HireRunRecord]s will have their `id` fields set.
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
  Future<List<HireRunRecord>> insert(
    _is.DatabaseSession session,
    List<HireRunRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<HireRunRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [HireRunRecord] and returns the inserted row.
  ///
  /// The returned [HireRunRecord] will have its `id` field set.
  Future<HireRunRecord> insertRow(
    _is.DatabaseSession session,
    HireRunRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<HireRunRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [HireRunRecord]s in the list and returns the resulting rows.
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
  /// The returned [HireRunRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireRunRecord>> upsert(
    _is.DatabaseSession session,
    List<HireRunRecord> rows, {
    required _is.ColumnSelections<HireRunRecordTable> conflictColumns,
    _is.ColumnSelections<HireRunRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HireRunRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<HireRunRecord>(
      rows,
      conflictColumns: conflictColumns(HireRunRecord.t),
      updateColumns: updateColumns?.call(HireRunRecord.t),
      updateWhere: updateWhere?.call(HireRunRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [HireRunRecord] and returns the resulting row.
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
  /// The returned [HireRunRecord] will have its `id` field set.
  Future<HireRunRecord?> upsertRow(
    _is.DatabaseSession session,
    HireRunRecord row, {
    required _is.ColumnSelections<HireRunRecordTable> conflictColumns,
    _is.ColumnSelections<HireRunRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HireRunRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<HireRunRecord>(
      row,
      conflictColumns: conflictColumns(HireRunRecord.t),
      updateColumns: updateColumns?.call(HireRunRecord.t),
      updateWhere: updateWhere?.call(HireRunRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [HireRunRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireRunRecord>> update(
    _is.DatabaseSession session,
    List<HireRunRecord> rows, {
    _is.ColumnSelections<HireRunRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<HireRunRecord>(
      rows,
      columns: columns?.call(HireRunRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [HireRunRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HireRunRecord> updateRow(
    _is.DatabaseSession session,
    HireRunRecord row, {
    _is.ColumnSelections<HireRunRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<HireRunRecord>(
      row,
      columns: columns?.call(HireRunRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HireRunRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<HireRunRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<HireRunRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<HireRunRecord>(
      id,
      columnValues: columnValues(HireRunRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HireRunRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireRunRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<HireRunRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<HireRunRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireRunRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRunRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<HireRunRecord>(
      columnValues: columnValues(HireRunRecord.t.updateTable),
      where: where(HireRunRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireRunRecord.t),
      orderByList: orderByList?.call(HireRunRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [HireRunRecord]s in the list and returns the deleted rows.
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
  Future<List<HireRunRecord>> delete(
    _is.DatabaseSession session,
    List<HireRunRecord> rows, {
    _is.OrderByBuilder<HireRunRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRunRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<HireRunRecord>(
      rows,
      orderBy: orderBy?.call(HireRunRecord.t),
      orderByList: orderByList?.call(HireRunRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [HireRunRecord].
  Future<HireRunRecord> deleteRow(
    _is.DatabaseSession session,
    HireRunRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HireRunRecord>(
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
  Future<List<HireRunRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HireRunRecordTable> where,
    _is.OrderByBuilder<HireRunRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRunRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<HireRunRecord>(
      where: where(HireRunRecord.t),
      orderBy: orderBy?.call(HireRunRecord.t),
      orderByList: orderByList?.call(HireRunRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireRunRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<HireRunRecord>(
      where: where?.call(HireRunRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HireRunRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HireRunRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HireRunRecord>(
      where: where(HireRunRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
