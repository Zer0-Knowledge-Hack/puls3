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

abstract class HirePaymentRecord
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
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
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [HirePaymentRecord]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
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
    _i1.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    HirePaymentRecordInclude? include,
  }) {
    return HirePaymentRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(HirePaymentRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
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
  @_i1.useResult
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
    extends _i1.UpdateTable<HirePaymentRecordTable> {
  HirePaymentRecordUpdateTable(super.table);

  _i1.ColumnValue<int, int> hireId(int value) => _i1.ColumnValue(
    table.hireId,
    value,
  );

  _i1.ColumnValue<String, String> transactionHash(String value) =>
      _i1.ColumnValue(
        table.transactionHash,
        value,
      );

  _i1.ColumnValue<int, int> jobId(int value) => _i1.ColumnValue(
    table.jobId,
    value,
  );

  _i1.ColumnValue<String, String> payer(String value) => _i1.ColumnValue(
    table.payer,
    value,
  );

  _i1.ColumnValue<String, String> payee(String value) => _i1.ColumnValue(
    table.payee,
    value,
  );

  _i1.ColumnValue<int, int> amount(int value) => _i1.ColumnValue(
    table.amount,
    value,
  );
}

class HirePaymentRecordTable extends _i1.Table<int?> {
  HirePaymentRecordTable({super.tableRelation})
    : super(tableName: 'hire_payment') {
    updateTable = HirePaymentRecordUpdateTable(this);
    hireId = _i1.ColumnInt(
      'hireId',
      this,
    );
    transactionHash = _i1.ColumnString(
      'transactionHash',
      this,
    );
    jobId = _i1.ColumnInt(
      'jobId',
      this,
    );
    payer = _i1.ColumnString(
      'payer',
      this,
    );
    payee = _i1.ColumnString(
      'payee',
      this,
    );
    amount = _i1.ColumnInt(
      'amount',
      this,
    );
  }

  late final HirePaymentRecordUpdateTable updateTable;

  late final _i1.ColumnInt hireId;

  late final _i1.ColumnString transactionHash;

  late final _i1.ColumnInt jobId;

  late final _i1.ColumnString payer;

  late final _i1.ColumnString payee;

  late final _i1.ColumnInt amount;

  @override
  List<_i1.Column> get columns => [
    id,
    hireId,
    transactionHash,
    jobId,
    payer,
    payee,
    amount,
  ];
}

class HirePaymentRecordInclude extends _i1.IncludeObject {
  HirePaymentRecordInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => HirePaymentRecord.t;
}

class HirePaymentRecordIncludeList extends _i1.IncludeList {
  HirePaymentRecordIncludeList._({
    _i1.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HirePaymentRecord.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => HirePaymentRecord.t;
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HirePaymentRecord>(
      where: where?.call(HirePaymentRecord.t),
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      orderDescending: orderDescending,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? offset,
    _i1.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HirePaymentRecord>(
      where: where?.call(HirePaymentRecord.t),
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HirePaymentRecord] by its [id] or null if no such row exists.
  Future<HirePaymentRecord?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
  Future<List<HirePaymentRecord>> insert(
    _i1.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<HirePaymentRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [HirePaymentRecord] and returns the inserted row.
  ///
  /// The returned [HirePaymentRecord] will have its `id` field set.
  Future<HirePaymentRecord> insertRow(
    _i1.DatabaseSession session,
    HirePaymentRecord row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<HirePaymentRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [HirePaymentRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<HirePaymentRecord>> update(
    _i1.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    _i1.ColumnSelections<HirePaymentRecordTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<HirePaymentRecord>(
      rows,
      columns: columns?.call(HirePaymentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HirePaymentRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HirePaymentRecord> updateRow(
    _i1.DatabaseSession session,
    HirePaymentRecord row, {
    _i1.ColumnSelections<HirePaymentRecordTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<HirePaymentRecordUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<HirePaymentRecord>(
      id,
      columnValues: columnValues(HirePaymentRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HirePaymentRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<HirePaymentRecord>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<HirePaymentRecordUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<HirePaymentRecordTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HirePaymentRecordTable>? orderBy,
    _i1.OrderByListBuilder<HirePaymentRecordTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<HirePaymentRecord>(
      columnValues: columnValues(HirePaymentRecord.t.updateTable),
      where: where(HirePaymentRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HirePaymentRecord.t),
      orderByList: orderByList?.call(HirePaymentRecord.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [HirePaymentRecord]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<HirePaymentRecord>> delete(
    _i1.DatabaseSession session,
    List<HirePaymentRecord> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<HirePaymentRecord>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [HirePaymentRecord].
  Future<HirePaymentRecord> deleteRow(
    _i1.DatabaseSession session,
    HirePaymentRecord row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HirePaymentRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<HirePaymentRecord>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HirePaymentRecordTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<HirePaymentRecord>(
      where: where(HirePaymentRecord.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HirePaymentRecordTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<HirePaymentRecord>(
      where: where?.call(HirePaymentRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HirePaymentRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HirePaymentRecordTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HirePaymentRecord>(
      where: where(HirePaymentRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
