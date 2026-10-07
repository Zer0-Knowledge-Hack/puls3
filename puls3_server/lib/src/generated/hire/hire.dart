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

abstract class HireRecord
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
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
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [HireRecord]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
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
    _i1.WhereExpressionBuilder<HireRecordTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HireRecordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HireRecordTable>? orderByList,
    HireRecordInclude? include,
  }) {
    return HireRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireRecord.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(HireRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
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
  @_i1.useResult
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

class HireRecordUpdateTable extends _i1.UpdateTable<HireRecordTable> {
  HireRecordUpdateTable(super.table);

  _i1.ColumnValue<String, String> consumer(String value) => _i1.ColumnValue(
    table.consumer,
    value,
  );

  _i1.ColumnValue<int, int> agentId(int value) => _i1.ColumnValue(
    table.agentId,
    value,
  );

  _i1.ColumnValue<int, int> price(int value) => _i1.ColumnValue(
    table.price,
    value,
  );

  _i1.ColumnValue<int, int> manifestVersion(int value) => _i1.ColumnValue(
    table.manifestVersion,
    value,
  );

  _i1.ColumnValue<int, int> expiredAt(int value) => _i1.ColumnValue(
    table.expiredAt,
    value,
  );
}

class HireRecordTable extends _i1.Table<int?> {
  HireRecordTable({super.tableRelation}) : super(tableName: 'hire') {
    updateTable = HireRecordUpdateTable(this);
    consumer = _i1.ColumnString(
      'consumer',
      this,
    );
    agentId = _i1.ColumnInt(
      'agentId',
      this,
    );
    price = _i1.ColumnInt(
      'price',
      this,
    );
    manifestVersion = _i1.ColumnInt(
      'manifestVersion',
      this,
    );
    expiredAt = _i1.ColumnInt(
      'expiredAt',
      this,
    );
  }

  late final HireRecordUpdateTable updateTable;

  late final _i1.ColumnString consumer;

  late final _i1.ColumnInt agentId;

  late final _i1.ColumnInt price;

  late final _i1.ColumnInt manifestVersion;

  late final _i1.ColumnInt expiredAt;

  @override
  List<_i1.Column> get columns => [
    id,
    consumer,
    agentId,
    price,
    manifestVersion,
    expiredAt,
  ];
}

class HireRecordInclude extends _i1.IncludeObject {
  HireRecordInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => HireRecord.t;
}

class HireRecordIncludeList extends _i1.IncludeList {
  HireRecordIncludeList._({
    _i1.WhereExpressionBuilder<HireRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HireRecord.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => HireRecord.t;
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HireRecordTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HireRecordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HireRecordTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HireRecord>(
      where: where?.call(HireRecord.t),
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      orderDescending: orderDescending,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HireRecordTable>? where,
    int? offset,
    _i1.OrderByBuilder<HireRecordTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<HireRecordTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HireRecord>(
      where: where?.call(HireRecord.t),
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HireRecord] by its [id] or null if no such row exists.
  Future<HireRecord?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
  Future<List<HireRecord>> insert(
    _i1.DatabaseSession session,
    List<HireRecord> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<HireRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [HireRecord] and returns the inserted row.
  ///
  /// The returned [HireRecord] will have its `id` field set.
  Future<HireRecord> insertRow(
    _i1.DatabaseSession session,
    HireRecord row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<HireRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [HireRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<HireRecord>> update(
    _i1.DatabaseSession session,
    List<HireRecord> rows, {
    _i1.ColumnSelections<HireRecordTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<HireRecord>(
      rows,
      columns: columns?.call(HireRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HireRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HireRecord> updateRow(
    _i1.DatabaseSession session,
    HireRecord row, {
    _i1.ColumnSelections<HireRecordTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<HireRecordUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<HireRecord>(
      id,
      columnValues: columnValues(HireRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HireRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<HireRecord>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<HireRecordUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<HireRecordTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<HireRecordTable>? orderBy,
    _i1.OrderByListBuilder<HireRecordTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<HireRecord>(
      columnValues: columnValues(HireRecord.t.updateTable),
      where: where(HireRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireRecord.t),
      orderByList: orderByList?.call(HireRecord.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [HireRecord]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<HireRecord>> delete(
    _i1.DatabaseSession session,
    List<HireRecord> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<HireRecord>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [HireRecord].
  Future<HireRecord> deleteRow(
    _i1.DatabaseSession session,
    HireRecord row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HireRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<HireRecord>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HireRecordTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<HireRecord>(
      where: where(HireRecord.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<HireRecordTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<HireRecord>(
      where: where?.call(HireRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HireRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<HireRecordTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HireRecord>(
      where: where(HireRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
