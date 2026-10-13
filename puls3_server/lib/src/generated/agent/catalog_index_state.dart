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

/// The catalog indexer's resume cursor, one row per network. It lets a pass
/// read only the registry events after the last ledger it processed.
abstract class CatalogIndexState
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  CatalogIndexState._({
    this.id,
    required this.network,
    required this.lastProcessedLedger,
    required this.updatedAt,
  });

  factory CatalogIndexState({
    int? id,
    required String network,
    required int lastProcessedLedger,
    required DateTime updatedAt,
  }) = _CatalogIndexStateImpl;

  factory CatalogIndexState.fromJson(Map<String, dynamic> jsonSerialization) {
    return CatalogIndexState(
      id: jsonSerialization['id'] as int?,
      network: jsonSerialization['network'] as String,
      lastProcessedLedger: jsonSerialization['lastProcessedLedger'] as int,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = CatalogIndexStateTable();

  static const db = CatalogIndexStateRepository._();

  @override
  int? id;

  /// The network the cursor is for (the Stellar network passphrase).
  String network;

  /// The last ledger the indexer fully processed.
  int lastProcessedLedger;

  /// When the cursor last advanced.
  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [CatalogIndexState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  CatalogIndexState copyWith({
    int? id,
    String? network,
    int? lastProcessedLedger,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'CatalogIndexState',
      if (id != null) 'id': id,
      'network': network,
      'lastProcessedLedger': lastProcessedLedger,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static CatalogIndexStateInclude include() {
    return CatalogIndexStateInclude._();
  }

  static CatalogIndexStateIncludeList includeList({
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CatalogIndexStateTable>? orderBy,
    _is.OrderByListBuilder<CatalogIndexStateTable>? orderByList,
    CatalogIndexStateInclude? include,
  }) {
    return CatalogIndexStateIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CatalogIndexState.t),
      orderByList: orderByList?.call(CatalogIndexState.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CatalogIndexStateImpl extends CatalogIndexState {
  _CatalogIndexStateImpl({
    int? id,
    required String network,
    required int lastProcessedLedger,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         network: network,
         lastProcessedLedger: lastProcessedLedger,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [CatalogIndexState]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  CatalogIndexState copyWith({
    Object? id = _Undefined,
    String? network,
    int? lastProcessedLedger,
    DateTime? updatedAt,
  }) {
    return CatalogIndexState(
      id: id is int? ? id : this.id,
      network: network ?? this.network,
      lastProcessedLedger: lastProcessedLedger ?? this.lastProcessedLedger,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CatalogIndexStateUpdateTable
    extends _is.UpdateTable<CatalogIndexStateTable> {
  CatalogIndexStateUpdateTable(super.table);

  _is.ColumnValue<String, String> network(String value) => _is.ColumnValue(
    table.network,
    value,
  );

  _is.ColumnValue<int, int> lastProcessedLedger(int value) => _is.ColumnValue(
    table.lastProcessedLedger,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class CatalogIndexStateTable extends _is.Table<int?> {
  CatalogIndexStateTable({super.tableRelation})
    : super(tableName: 'catalog_index_state') {
    updateTable = CatalogIndexStateUpdateTable(this);
    network = _is.ColumnString(
      'network',
      this,
    );
    lastProcessedLedger = _is.ColumnInt(
      'lastProcessedLedger',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final CatalogIndexStateUpdateTable updateTable;

  /// The network the cursor is for (the Stellar network passphrase).
  late final _is.ColumnString network;

  /// The last ledger the indexer fully processed.
  late final _is.ColumnInt lastProcessedLedger;

  /// When the cursor last advanced.
  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    network,
    lastProcessedLedger,
    updatedAt,
  ];
}

class CatalogIndexStateInclude extends _is.IncludeObject {
  CatalogIndexStateInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => CatalogIndexState.t;
}

class CatalogIndexStateIncludeList extends _is.IncludeList {
  CatalogIndexStateIncludeList._({
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CatalogIndexState.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => CatalogIndexState.t;
}

class CatalogIndexStateRepository {
  const CatalogIndexStateRepository._();

  /// Returns a list of [CatalogIndexState]s matching the given query parameters.
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
  Future<List<CatalogIndexState>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CatalogIndexStateTable>? orderBy,
    _is.OrderByListBuilder<CatalogIndexStateTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CatalogIndexState>(
      where: where?.call(CatalogIndexState.t),
      orderBy: orderBy?.call(CatalogIndexState.t),
      orderByList: orderByList?.call(CatalogIndexState.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CatalogIndexState] matching the given query parameters.
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
  Future<CatalogIndexState?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? where,
    int? offset,
    _is.OrderByBuilder<CatalogIndexStateTable>? orderBy,
    _is.OrderByListBuilder<CatalogIndexStateTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CatalogIndexState>(
      where: where?.call(CatalogIndexState.t),
      orderBy: orderBy?.call(CatalogIndexState.t),
      orderByList: orderByList?.call(CatalogIndexState.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CatalogIndexState] by its [id] or null if no such row exists.
  Future<CatalogIndexState?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CatalogIndexState>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CatalogIndexState]s in the list and returns the inserted rows.
  ///
  /// The returned [CatalogIndexState]s will have their `id` fields set.
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
  Future<List<CatalogIndexState>> insert(
    _is.DatabaseSession session,
    List<CatalogIndexState> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CatalogIndexState>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CatalogIndexState] and returns the inserted row.
  ///
  /// The returned [CatalogIndexState] will have its `id` field set.
  Future<CatalogIndexState> insertRow(
    _is.DatabaseSession session,
    CatalogIndexState row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<CatalogIndexState>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CatalogIndexState]s in the list and returns the resulting rows.
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
  /// The returned [CatalogIndexState]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CatalogIndexState>> upsert(
    _is.DatabaseSession session,
    List<CatalogIndexState> rows, {
    required _is.ColumnSelections<CatalogIndexStateTable> conflictColumns,
    _is.ColumnSelections<CatalogIndexStateTable>? updateColumns,
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CatalogIndexState>(
      rows,
      conflictColumns: conflictColumns(CatalogIndexState.t),
      updateColumns: updateColumns?.call(CatalogIndexState.t),
      updateWhere: updateWhere?.call(CatalogIndexState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CatalogIndexState] and returns the resulting row.
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
  /// The returned [CatalogIndexState] will have its `id` field set.
  Future<CatalogIndexState?> upsertRow(
    _is.DatabaseSession session,
    CatalogIndexState row, {
    required _is.ColumnSelections<CatalogIndexStateTable> conflictColumns,
    _is.ColumnSelections<CatalogIndexStateTable>? updateColumns,
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CatalogIndexState>(
      row,
      conflictColumns: conflictColumns(CatalogIndexState.t),
      updateColumns: updateColumns?.call(CatalogIndexState.t),
      updateWhere: updateWhere?.call(CatalogIndexState.t),
      transaction: transaction,
    );
  }

  /// Updates all [CatalogIndexState]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CatalogIndexState>> update(
    _is.DatabaseSession session,
    List<CatalogIndexState> rows, {
    _is.ColumnSelections<CatalogIndexStateTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CatalogIndexState>(
      rows,
      columns: columns?.call(CatalogIndexState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CatalogIndexState]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CatalogIndexState> updateRow(
    _is.DatabaseSession session,
    CatalogIndexState row, {
    _is.ColumnSelections<CatalogIndexStateTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<CatalogIndexState>(
      row,
      columns: columns?.call(CatalogIndexState.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CatalogIndexState] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CatalogIndexState?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<CatalogIndexStateUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<CatalogIndexState>(
      id,
      columnValues: columnValues(CatalogIndexState.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CatalogIndexState]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CatalogIndexState>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<CatalogIndexStateUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<CatalogIndexStateTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<CatalogIndexStateTable>? orderBy,
    _is.OrderByListBuilder<CatalogIndexStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CatalogIndexState>(
      columnValues: columnValues(CatalogIndexState.t.updateTable),
      where: where(CatalogIndexState.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CatalogIndexState.t),
      orderByList: orderByList?.call(CatalogIndexState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CatalogIndexState]s in the list and returns the deleted rows.
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
  Future<List<CatalogIndexState>> delete(
    _is.DatabaseSession session,
    List<CatalogIndexState> rows, {
    _is.OrderByBuilder<CatalogIndexStateTable>? orderBy,
    _is.OrderByListBuilder<CatalogIndexStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CatalogIndexState>(
      rows,
      orderBy: orderBy?.call(CatalogIndexState.t),
      orderByList: orderByList?.call(CatalogIndexState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CatalogIndexState].
  Future<CatalogIndexState> deleteRow(
    _is.DatabaseSession session,
    CatalogIndexState row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CatalogIndexState>(
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
  Future<List<CatalogIndexState>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CatalogIndexStateTable> where,
    _is.OrderByBuilder<CatalogIndexStateTable>? orderBy,
    _is.OrderByListBuilder<CatalogIndexStateTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CatalogIndexState>(
      where: where(CatalogIndexState.t),
      orderBy: orderBy?.call(CatalogIndexState.t),
      orderByList: orderByList?.call(CatalogIndexState.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<CatalogIndexStateTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<CatalogIndexState>(
      where: where?.call(CatalogIndexState.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CatalogIndexState] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<CatalogIndexStateTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CatalogIndexState>(
      where: where(CatalogIndexState.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
