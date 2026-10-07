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

abstract class HireRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  HireRecord._({
    this.id,
    required this.consumer,
    required this.agentId,
    required this.price,
    required this.manifestVersion,
    required this.expiredAt,
  });

  factory HireRecord({
    int? id,
    required String consumer,
    required int agentId,
    required int price,
    required int manifestVersion,
    required int expiredAt,
  }) = _HireRecordImpl;

  factory HireRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireRecord(
      id: jsonSerialization['id'] as int?,
      consumer: jsonSerialization['consumer'] as String,
      agentId: jsonSerialization['agentId'] as int,
      price: jsonSerialization['price'] as int,
      manifestVersion: jsonSerialization['manifestVersion'] as int,
      expiredAt: jsonSerialization['expiredAt'] as int,
    );
  }

  static final t = HireRecordTable();

  static const db = HireRecordRepository._();

  @override
  int? id;

  String consumer;

  int agentId;

  int price;

  int manifestVersion;

  int expiredAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [HireRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  HireRecord copyWith({
    int? id,
    String? consumer,
    int? agentId,
    int? price,
    int? manifestVersion,
    int? expiredAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireRecord',
      if (id != null) 'id': id,
      'consumer': consumer,
      'agentId': agentId,
      'price': price,
      'manifestVersion': manifestVersion,
      'expiredAt': expiredAt,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static HireRecordInclude include() {
    return HireRecordInclude._();
  }

  static HireRecordIncludeList includeList({
    _is.WhereExpressionBuilder<HireRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRecordTable>? orderByList,
    HireRecordInclude? include,
  }) {
    return HireRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireRecordImpl extends HireRecord {
  _HireRecordImpl({
    int? id,
    required String consumer,
    required int agentId,
    required int price,
    required int manifestVersion,
    required int expiredAt,
  }) : super._(
         id: id,
         consumer: consumer,
         agentId: agentId,
         price: price,
         manifestVersion: manifestVersion,
         expiredAt: expiredAt,
       );

  /// Returns a shallow copy of this [HireRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  HireRecord copyWith({
    Object? id = _Undefined,
    String? consumer,
    int? agentId,
    int? price,
    int? manifestVersion,
    int? expiredAt,
  }) {
    return HireRecord(
      id: id is int? ? id : this.id,
      consumer: consumer ?? this.consumer,
      agentId: agentId ?? this.agentId,
      price: price ?? this.price,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      expiredAt: expiredAt ?? this.expiredAt,
    );
  }
}

class HireRecordUpdateTable extends _is.UpdateTable<HireRecordTable> {
  HireRecordUpdateTable(super.table);

  _is.ColumnValue<String, String> consumer(String value) => _is.ColumnValue(
    table.consumer,
    value,
  );

  _is.ColumnValue<int, int> agentId(int value) => _is.ColumnValue(
    table.agentId,
    value,
  );

  _is.ColumnValue<int, int> price(int value) => _is.ColumnValue(
    table.price,
    value,
  );

  _is.ColumnValue<int, int> manifestVersion(int value) => _is.ColumnValue(
    table.manifestVersion,
    value,
  );

  _is.ColumnValue<int, int> expiredAt(int value) => _is.ColumnValue(
    table.expiredAt,
    value,
  );
}

class HireRecordTable extends _is.Table<int?> {
  HireRecordTable({super.tableRelation}) : super(tableName: 'hire') {
    updateTable = HireRecordUpdateTable(this);
    consumer = _is.ColumnString(
      'consumer',
      this,
    );
    agentId = _is.ColumnInt(
      'agentId',
      this,
    );
    price = _is.ColumnInt(
      'price',
      this,
    );
    manifestVersion = _is.ColumnInt(
      'manifestVersion',
      this,
    );
    expiredAt = _is.ColumnInt(
      'expiredAt',
      this,
    );
  }

  late final HireRecordUpdateTable updateTable;

  late final _is.ColumnString consumer;

  late final _is.ColumnInt agentId;

  late final _is.ColumnInt price;

  late final _is.ColumnInt manifestVersion;

  late final _is.ColumnInt expiredAt;

  @override
  List<_is.Column> get columns => [
    id,
    consumer,
    agentId,
    price,
    manifestVersion,
    expiredAt,
  ];
}

class HireRecordInclude extends _is.IncludeObject {
  HireRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => HireRecord.t;
}

class HireRecordIncludeList extends _is.IncludeList {
  HireRecordIncludeList._({
    _is.WhereExpressionBuilder<HireRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HireRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => HireRecord.t;
}

class HireRecordRepository {
  const HireRecordRepository._();

  /// Returns a list of [HireRecord]s matching the given query parameters.
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
  Future<List<HireRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HireRecord>(
      where: where?.call(HireRecord.t),
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [HireRecord] matching the given query parameters.
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
  Future<HireRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<HireRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HireRecord>(
      where: where?.call(HireRecord.t),
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HireRecord] by its [id] or null if no such row exists.
  Future<HireRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<HireRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [HireRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [HireRecord]s will have their `id` fields set.
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
  Future<List<HireRecord>> insert(
    _is.DatabaseSession session,
    List<HireRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<HireRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [HireRecord] and returns the inserted row.
  ///
  /// The returned [HireRecord] will have its `id` field set.
  Future<HireRecord> insertRow(
    _is.DatabaseSession session,
    HireRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<HireRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [HireRecord]s in the list and returns the resulting rows.
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
  /// The returned [HireRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireRecord>> upsert(
    _is.DatabaseSession session,
    List<HireRecord> rows, {
    required _is.ColumnSelections<HireRecordTable> conflictColumns,
    _is.ColumnSelections<HireRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HireRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<HireRecord>(
      rows,
      conflictColumns: conflictColumns(HireRecord.t),
      updateColumns: updateColumns?.call(HireRecord.t),
      updateWhere: updateWhere?.call(HireRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [HireRecord] and returns the resulting row.
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
  /// The returned [HireRecord] will have its `id` field set.
  Future<HireRecord?> upsertRow(
    _is.DatabaseSession session,
    HireRecord row, {
    required _is.ColumnSelections<HireRecordTable> conflictColumns,
    _is.ColumnSelections<HireRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HireRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<HireRecord>(
      row,
      conflictColumns: conflictColumns(HireRecord.t),
      updateColumns: updateColumns?.call(HireRecord.t),
      updateWhere: updateWhere?.call(HireRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [HireRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireRecord>> update(
    _is.DatabaseSession session,
    List<HireRecord> rows, {
    _is.ColumnSelections<HireRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<HireRecord>(
      rows,
      columns: columns?.call(HireRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [HireRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HireRecord> updateRow(
    _is.DatabaseSession session,
    HireRecord row, {
    _is.ColumnSelections<HireRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<HireRecord>(
      row,
      columns: columns?.call(HireRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HireRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<HireRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<HireRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<HireRecord>(
      id,
      columnValues: columnValues(HireRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HireRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<HireRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<HireRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<HireRecord>(
      columnValues: columnValues(HireRecord.t.updateTable),
      where: where(HireRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [HireRecord]s in the list and returns the deleted rows.
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
  Future<List<HireRecord>> delete(
    _is.DatabaseSession session,
    List<HireRecord> rows, {
    _is.OrderByBuilder<HireRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<HireRecord>(
      rows,
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [HireRecord].
  Future<HireRecord> deleteRow(
    _is.DatabaseSession session,
    HireRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HireRecord>(
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
  Future<List<HireRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HireRecordTable> where,
    _is.OrderByBuilder<HireRecordTable>? orderBy,
    _is.OrderByListBuilder<HireRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<HireRecord>(
      where: where(HireRecord.t),
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<HireRecord>(
      where: where?.call(HireRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HireRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HireRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HireRecord>(
      where: where(HireRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
