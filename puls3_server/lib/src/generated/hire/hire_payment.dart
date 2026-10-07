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

abstract class HirePaymentRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  HirePaymentRecord._({
    this.id,
    required this.hireId,
    required this.transactionHash,
    required this.jobId,
    required this.payer,
    required this.payee,
    required this.amount,
  });

  factory HirePaymentRecord({
    int? id,
    required int hireId,
    required String transactionHash,
    required int jobId,
    required String payer,
    required String payee,
    required int amount,
  }) = _HirePaymentRecordImpl;

  factory HirePaymentRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return HirePaymentRecord(
      id: jsonSerialization['id'] as int?,
      hireId: jsonSerialization['hireId'] as int,
      transactionHash: jsonSerialization['transactionHash'] as String,
      jobId: jsonSerialization['jobId'] as int,
      payer: jsonSerialization['payer'] as String,
      payee: jsonSerialization['payee'] as String,
      amount: jsonSerialization['amount'] as int,
    );
  }

  static final t = HirePaymentRecordTable();

  static const db = HirePaymentRecordRepository._();

  @override
  int? id;

  int hireId;

  String transactionHash;

  int jobId;

  String payer;

  String payee;

  int amount;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [HirePaymentRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  HirePaymentRecord copyWith({
    int? id,
    int? hireId,
    String? transactionHash,
    int? jobId,
    String? payer,
    String? payee,
    int? amount,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HirePaymentRecord',
      if (id != null) 'id': id,
      'hireId': hireId,
      'transactionHash': transactionHash,
      'jobId': jobId,
      'payer': payer,
      'payee': payee,
      'amount': amount,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static HirePaymentRecordInclude include() {
    return HirePaymentRecordInclude._();
  }

  static HirePaymentRecordIncludeList includeList({
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _is.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    HirePaymentRecordInclude? include,
  }) {
    return HirePaymentRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HirePaymentRecordImpl extends HirePaymentRecord {
  _HirePaymentRecordImpl({
    int? id,
    required int hireId,
    required String transactionHash,
    required int jobId,
    required String payer,
    required String payee,
    required int amount,
  }) : super._(
         id: id,
         hireId: hireId,
         transactionHash: transactionHash,
         jobId: jobId,
         payer: payer,
         payee: payee,
         amount: amount,
       );

  /// Returns a shallow copy of this [HirePaymentRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  HirePaymentRecord copyWith({
    Object? id = _Undefined,
    int? hireId,
    String? transactionHash,
    int? jobId,
    String? payer,
    String? payee,
    int? amount,
  }) {
    return HirePaymentRecord(
      id: id is int? ? id : this.id,
      hireId: hireId ?? this.hireId,
      transactionHash: transactionHash ?? this.transactionHash,
      jobId: jobId ?? this.jobId,
      payer: payer ?? this.payer,
      payee: payee ?? this.payee,
      amount: amount ?? this.amount,
    );
  }
}

class HirePaymentRecordUpdateTable
    extends _is.UpdateTable<HirePaymentRecordTable> {
  HirePaymentRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> hireId(int value) => _is.ColumnValue(
    table.hireId,
    value,
  );

  _is.ColumnValue<String, String> transactionHash(String value) =>
      _is.ColumnValue(
        table.transactionHash,
        value,
      );

  _is.ColumnValue<int, int> jobId(int value) => _is.ColumnValue(
    table.jobId,
    value,
  );

  _is.ColumnValue<String, String> payer(String value) => _is.ColumnValue(
    table.payer,
    value,
  );

  _is.ColumnValue<String, String> payee(String value) => _is.ColumnValue(
    table.payee,
    value,
  );

  _is.ColumnValue<int, int> amount(int value) => _is.ColumnValue(
    table.amount,
    value,
  );
}

class HirePaymentRecordTable extends _is.Table<int?> {
  HirePaymentRecordTable({super.tableRelation})
    : super(tableName: 'hire_payment') {
    updateTable = HirePaymentRecordUpdateTable(this);
    hireId = _is.ColumnInt(
      'hireId',
      this,
    );
    transactionHash = _is.ColumnString(
      'transactionHash',
      this,
    );
    jobId = _is.ColumnInt(
      'jobId',
      this,
    );
    payer = _is.ColumnString(
      'payer',
      this,
    );
    payee = _is.ColumnString(
      'payee',
      this,
    );
    amount = _is.ColumnInt(
      'amount',
      this,
    );
  }

  late final HirePaymentRecordUpdateTable updateTable;

  late final _is.ColumnInt hireId;

  late final _is.ColumnString transactionHash;

  late final _is.ColumnInt jobId;

  late final _is.ColumnString payer;

  late final _is.ColumnString payee;

  late final _is.ColumnInt amount;

  @override
  List<_is.Column> get columns => [
    id,
    hireId,
    transactionHash,
    jobId,
    payer,
    payee,
    amount,
  ];
}

class HirePaymentRecordInclude extends _is.IncludeObject {
  HirePaymentRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => HirePaymentRecord.t;
}

class HirePaymentRecordIncludeList extends _is.IncludeList {
  HirePaymentRecordIncludeList._({
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HirePaymentRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => HirePaymentRecord.t;
}

class HirePaymentRecordRepository {
  const HirePaymentRecordRepository._();

  /// Returns a list of [HirePaymentRecord]s matching the given query parameters.
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
  Future<List<HirePaymentRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _is.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HirePaymentRecord>(
      where: where?.call(HirePaymentRecord.t),
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [HirePaymentRecord] matching the given query parameters.
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
  Future<HirePaymentRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _is.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HirePaymentRecord>(
      where: where?.call(HirePaymentRecord.t),
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HirePaymentRecord] by its [id] or null if no such row exists.
  Future<HirePaymentRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<HirePaymentRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [HirePaymentRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [HirePaymentRecord]s will have their `id` fields set.
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
  Future<List<HirePaymentRecord>> insert(
    _is.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<HirePaymentRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [HirePaymentRecord] and returns the inserted row.
  ///
  /// The returned [HirePaymentRecord] will have its `id` field set.
  Future<HirePaymentRecord> insertRow(
    _is.DatabaseSession session,
    HirePaymentRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<HirePaymentRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [HirePaymentRecord]s in the list and returns the resulting rows.
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
  /// The returned [HirePaymentRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HirePaymentRecord>> upsert(
    _is.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    required _is.ColumnSelections<HirePaymentRecordTable> conflictColumns,
    _is.ColumnSelections<HirePaymentRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<HirePaymentRecord>(
      rows,
      conflictColumns: conflictColumns(HirePaymentRecord.t),
      updateColumns: updateColumns?.call(HirePaymentRecord.t),
      updateWhere: updateWhere?.call(HirePaymentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [HirePaymentRecord] and returns the resulting row.
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
  /// The returned [HirePaymentRecord] will have its `id` field set.
  Future<HirePaymentRecord?> upsertRow(
    _is.DatabaseSession session,
    HirePaymentRecord row, {
    required _is.ColumnSelections<HirePaymentRecordTable> conflictColumns,
    _is.ColumnSelections<HirePaymentRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<HirePaymentRecord>(
      row,
      conflictColumns: conflictColumns(HirePaymentRecord.t),
      updateColumns: updateColumns?.call(HirePaymentRecord.t),
      updateWhere: updateWhere?.call(HirePaymentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [HirePaymentRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HirePaymentRecord>> update(
    _is.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    _is.ColumnSelections<HirePaymentRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<HirePaymentRecord>(
      rows,
      columns: columns?.call(HirePaymentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [HirePaymentRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HirePaymentRecord> updateRow(
    _is.DatabaseSession session,
    HirePaymentRecord row, {
    _is.ColumnSelections<HirePaymentRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<HirePaymentRecord>(
      row,
      columns: columns?.call(HirePaymentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HirePaymentRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<HirePaymentRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<HirePaymentRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<HirePaymentRecord>(
      id,
      columnValues: columnValues(HirePaymentRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HirePaymentRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HirePaymentRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<HirePaymentRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<HirePaymentRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _is.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<HirePaymentRecord>(
      columnValues: columnValues(HirePaymentRecord.t.updateTable),
      where: where(HirePaymentRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [HirePaymentRecord]s in the list and returns the deleted rows.
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
  Future<List<HirePaymentRecord>> delete(
    _is.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    _is.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _is.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<HirePaymentRecord>(
      rows,
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [HirePaymentRecord].
  Future<HirePaymentRecord> deleteRow(
    _is.DatabaseSession session,
    HirePaymentRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HirePaymentRecord>(
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
  Future<List<HirePaymentRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HirePaymentRecordTable> where,
    _is.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _is.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<HirePaymentRecord>(
      where: where(HirePaymentRecord.t),
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<HirePaymentRecord>(
      where: where?.call(HirePaymentRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HirePaymentRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HirePaymentRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HirePaymentRecord>(
      where: where(HirePaymentRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
