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

/// What the server read of an escrow job in a final state (`Completed`,
/// `Rejected` or `Expired`), kept so a rating still counts after the job's
/// entry archives (#273). A final state never changes, so the row is a cache
/// of the chain: it is read only for an archived entry, never over a job that
/// `get_job` can answer.
abstract class TerminalJobFact
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  TerminalJobFact._({
    this.id,
    required this.escrow,
    required this.jobId,
    required this.client,
    required this.agentId,
    required this.state,
    required this.observedAt,
  });

  factory TerminalJobFact({
    int? id,
    required String escrow,
    required int jobId,
    required String client,
    required int agentId,
    required String state,
    required DateTime observedAt,
  }) = _TerminalJobFactImpl;

  factory TerminalJobFact.fromJson(Map<String, dynamic> jsonSerialization) {
    return TerminalJobFact(
      id: jsonSerialization['id'] as int?,
      escrow: jsonSerialization['escrow'] as String,
      jobId: jsonSerialization['jobId'] as int,
      client: jsonSerialization['client'] as String,
      agentId: jsonSerialization['agentId'] as int,
      state: jsonSerialization['state'] as String,
      observedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['observedAt'],
      ),
    );
  }

  static final t = TerminalJobFactTable();

  static const db = TerminalJobFactRepository._();

  @override
  int? id;

  /// StrKey of the escrow contract the job was read from.
  String escrow;

  /// The job id on that escrow.
  int jobId;

  /// StrKey of the job's client.
  String client;

  /// The hired agent's registry id.
  int agentId;

  /// The final `JobState` name: completed, rejected or expired.
  String state;

  /// When the server read it from the chain.
  DateTime observedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [TerminalJobFact]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  TerminalJobFact copyWith({
    int? id,
    String? escrow,
    int? jobId,
    String? client,
    int? agentId,
    String? state,
    DateTime? observedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TerminalJobFact',
      if (id != null) 'id': id,
      'escrow': escrow,
      'jobId': jobId,
      'client': client,
      'agentId': agentId,
      'state': state,
      'observedAt': observedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static TerminalJobFactInclude include() {
    return TerminalJobFactInclude._();
  }

  static TerminalJobFactIncludeList includeList({
    _is.WhereExpressionBuilder<TerminalJobFactTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TerminalJobFactTable>? orderBy,
    _is.OrderByListBuilder<TerminalJobFactTable>? orderByList,
    TerminalJobFactInclude? include,
  }) {
    return TerminalJobFactIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(TerminalJobFact.t),
      orderByList: orderByList?.call(TerminalJobFact.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TerminalJobFactImpl extends TerminalJobFact {
  _TerminalJobFactImpl({
    int? id,
    required String escrow,
    required int jobId,
    required String client,
    required int agentId,
    required String state,
    required DateTime observedAt,
  }) : super._(
         id: id,
         escrow: escrow,
         jobId: jobId,
         client: client,
         agentId: agentId,
         state: state,
         observedAt: observedAt,
       );

  /// Returns a shallow copy of this [TerminalJobFact]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  TerminalJobFact copyWith({
    Object? id = _Undefined,
    String? escrow,
    int? jobId,
    String? client,
    int? agentId,
    String? state,
    DateTime? observedAt,
  }) {
    return TerminalJobFact(
      id: id is int? ? id : this.id,
      escrow: escrow ?? this.escrow,
      jobId: jobId ?? this.jobId,
      client: client ?? this.client,
      agentId: agentId ?? this.agentId,
      state: state ?? this.state,
      observedAt: observedAt ?? this.observedAt,
    );
  }
}

class TerminalJobFactUpdateTable extends _is.UpdateTable<TerminalJobFactTable> {
  TerminalJobFactUpdateTable(super.table);

  _is.ColumnValue<String, String> escrow(String value) => _is.ColumnValue(
    table.escrow,
    value,
  );

  _is.ColumnValue<int, int> jobId(int value) => _is.ColumnValue(
    table.jobId,
    value,
  );

  _is.ColumnValue<String, String> client(String value) => _is.ColumnValue(
    table.client,
    value,
  );

  _is.ColumnValue<int, int> agentId(int value) => _is.ColumnValue(
    table.agentId,
    value,
  );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> observedAt(DateTime value) =>
      _is.ColumnValue(
        table.observedAt,
        value,
      );
}

class TerminalJobFactTable extends _is.Table<int?> {
  TerminalJobFactTable({super.tableRelation})
    : super(tableName: 'terminal_job_fact') {
    updateTable = TerminalJobFactUpdateTable(this);
    escrow = _is.ColumnString(
      'escrow',
      this,
    );
    jobId = _is.ColumnInt(
      'jobId',
      this,
    );
    client = _is.ColumnString(
      'client',
      this,
    );
    agentId = _is.ColumnInt(
      'agentId',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    observedAt = _is.ColumnDateTime(
      'observedAt',
      this,
    );
  }

  late final TerminalJobFactUpdateTable updateTable;

  /// StrKey of the escrow contract the job was read from.
  late final _is.ColumnString escrow;

  /// The job id on that escrow.
  late final _is.ColumnInt jobId;

  /// StrKey of the job's client.
  late final _is.ColumnString client;

  /// The hired agent's registry id.
  late final _is.ColumnInt agentId;

  /// The final `JobState` name: completed, rejected or expired.
  late final _is.ColumnString state;

  /// When the server read it from the chain.
  late final _is.ColumnDateTime observedAt;

  @override
  List<_is.Column> get columns => [
    id,
    escrow,
    jobId,
    client,
    agentId,
    state,
    observedAt,
  ];
}

class TerminalJobFactInclude extends _is.IncludeObject {
  TerminalJobFactInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => TerminalJobFact.t;
}

class TerminalJobFactIncludeList extends _is.IncludeList {
  TerminalJobFactIncludeList._({
    _is.WhereExpressionBuilder<TerminalJobFactTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(TerminalJobFact.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => TerminalJobFact.t;
}

class TerminalJobFactRepository {
  const TerminalJobFactRepository._();

  /// Returns a list of [TerminalJobFact]s matching the given query parameters.
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
  Future<List<TerminalJobFact>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TerminalJobFactTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TerminalJobFactTable>? orderBy,
    _is.OrderByListBuilder<TerminalJobFactTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<TerminalJobFact>(
      where: where?.call(TerminalJobFact.t),
      orderBy: orderBy?.call(TerminalJobFact.t),
      orderByList: orderByList?.call(TerminalJobFact.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [TerminalJobFact] matching the given query parameters.
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
  Future<TerminalJobFact?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TerminalJobFactTable>? where,
    int? offset,
    _is.OrderByBuilder<TerminalJobFactTable>? orderBy,
    _is.OrderByListBuilder<TerminalJobFactTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<TerminalJobFact>(
      where: where?.call(TerminalJobFact.t),
      orderBy: orderBy?.call(TerminalJobFact.t),
      orderByList: orderByList?.call(TerminalJobFact.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [TerminalJobFact] by its [id] or null if no such row exists.
  Future<TerminalJobFact?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<TerminalJobFact>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [TerminalJobFact]s in the list and returns the inserted rows.
  ///
  /// The returned [TerminalJobFact]s will have their `id` fields set.
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
  Future<List<TerminalJobFact>> insert(
    _is.DatabaseSession session,
    List<TerminalJobFact> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<TerminalJobFact>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [TerminalJobFact] and returns the inserted row.
  ///
  /// The returned [TerminalJobFact] will have its `id` field set.
  Future<TerminalJobFact> insertRow(
    _is.DatabaseSession session,
    TerminalJobFact row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<TerminalJobFact>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [TerminalJobFact]s in the list and returns the resulting rows.
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
  /// The returned [TerminalJobFact]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<TerminalJobFact>> upsert(
    _is.DatabaseSession session,
    List<TerminalJobFact> rows, {
    required _is.ColumnSelections<TerminalJobFactTable> conflictColumns,
    _is.ColumnSelections<TerminalJobFactTable>? updateColumns,
    _is.WhereExpressionBuilder<TerminalJobFactTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<TerminalJobFact>(
      rows,
      conflictColumns: conflictColumns(TerminalJobFact.t),
      updateColumns: updateColumns?.call(TerminalJobFact.t),
      updateWhere: updateWhere?.call(TerminalJobFact.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [TerminalJobFact] and returns the resulting row.
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
  /// The returned [TerminalJobFact] will have its `id` field set.
  Future<TerminalJobFact?> upsertRow(
    _is.DatabaseSession session,
    TerminalJobFact row, {
    required _is.ColumnSelections<TerminalJobFactTable> conflictColumns,
    _is.ColumnSelections<TerminalJobFactTable>? updateColumns,
    _is.WhereExpressionBuilder<TerminalJobFactTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<TerminalJobFact>(
      row,
      conflictColumns: conflictColumns(TerminalJobFact.t),
      updateColumns: updateColumns?.call(TerminalJobFact.t),
      updateWhere: updateWhere?.call(TerminalJobFact.t),
      transaction: transaction,
    );
  }

  /// Updates all [TerminalJobFact]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<TerminalJobFact>> update(
    _is.DatabaseSession session,
    List<TerminalJobFact> rows, {
    _is.ColumnSelections<TerminalJobFactTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<TerminalJobFact>(
      rows,
      columns: columns?.call(TerminalJobFact.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [TerminalJobFact]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<TerminalJobFact> updateRow(
    _is.DatabaseSession session,
    TerminalJobFact row, {
    _is.ColumnSelections<TerminalJobFactTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<TerminalJobFact>(
      row,
      columns: columns?.call(TerminalJobFact.t),
      transaction: transaction,
    );
  }

  /// Updates a single [TerminalJobFact] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<TerminalJobFact?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<TerminalJobFactUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<TerminalJobFact>(
      id,
      columnValues: columnValues(TerminalJobFact.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [TerminalJobFact]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<TerminalJobFact>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<TerminalJobFactUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<TerminalJobFactTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TerminalJobFactTable>? orderBy,
    _is.OrderByListBuilder<TerminalJobFactTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<TerminalJobFact>(
      columnValues: columnValues(TerminalJobFact.t.updateTable),
      where: where(TerminalJobFact.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(TerminalJobFact.t),
      orderByList: orderByList?.call(TerminalJobFact.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [TerminalJobFact]s in the list and returns the deleted rows.
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
  Future<List<TerminalJobFact>> delete(
    _is.DatabaseSession session,
    List<TerminalJobFact> rows, {
    _is.OrderByBuilder<TerminalJobFactTable>? orderBy,
    _is.OrderByListBuilder<TerminalJobFactTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<TerminalJobFact>(
      rows,
      orderBy: orderBy?.call(TerminalJobFact.t),
      orderByList: orderByList?.call(TerminalJobFact.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [TerminalJobFact].
  Future<TerminalJobFact> deleteRow(
    _is.DatabaseSession session,
    TerminalJobFact row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<TerminalJobFact>(
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
  Future<List<TerminalJobFact>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<TerminalJobFactTable> where,
    _is.OrderByBuilder<TerminalJobFactTable>? orderBy,
    _is.OrderByListBuilder<TerminalJobFactTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<TerminalJobFact>(
      where: where(TerminalJobFact.t),
      orderBy: orderBy?.call(TerminalJobFact.t),
      orderByList: orderByList?.call(TerminalJobFact.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TerminalJobFactTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<TerminalJobFact>(
      where: where?.call(TerminalJobFact.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [TerminalJobFact] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<TerminalJobFactTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<TerminalJobFact>(
      where: where(TerminalJobFact.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
