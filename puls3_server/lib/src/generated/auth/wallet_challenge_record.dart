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

/// One issued SEP-10 challenge. Server-only: the stored XDR and hash never
/// cross an endpoint. The client receives [WalletChallenge] instead.
abstract class WalletChallengeRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WalletChallengeRecord._({
    this.id,
    required this.challengeId,
    required this.wallet,
    required this.challengeXdr,
    required this.transactionHash,
    required this.expiresAt,
    required this.createdAt,
    this.consumedAt,
  });

  factory WalletChallengeRecord({
    int? id,
    required String challengeId,
    required String wallet,
    required String challengeXdr,
    required String transactionHash,
    required DateTime expiresAt,
    required DateTime createdAt,
    DateTime? consumedAt,
  }) = _WalletChallengeRecordImpl;

  factory WalletChallengeRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return WalletChallengeRecord(
      id: jsonSerialization['id'] as int?,
      challengeId: jsonSerialization['challengeId'] as String,
      wallet: jsonSerialization['wallet'] as String,
      challengeXdr: jsonSerialization['challengeXdr'] as String,
      transactionHash: jsonSerialization['transactionHash'] as String,
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      consumedAt: jsonSerialization['consumedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['consumedAt']),
    );
  }

  static final t = WalletChallengeRecordTable();

  static const db = WalletChallengeRecordRepository._();

  @override
  int? id;

  /// Opaque id returned to the client.
  String challengeId;

  /// Stellar G-address the challenge was issued for.
  String wallet;

  /// Base64 unsigned server-signed challenge XDR.
  String challengeXdr;

  /// Hex transaction hash of the challenge.
  String transactionHash;

  /// End of the time bounds. A challenge past this instant is expired.
  DateTime expiresAt;

  /// When the challenge was issued.
  DateTime createdAt;

  /// Set when a verification consumes the challenge.
  DateTime? consumedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WalletChallengeRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WalletChallengeRecord copyWith({
    int? id,
    String? challengeId,
    String? wallet,
    String? challengeXdr,
    String? transactionHash,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? consumedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WalletChallengeRecord',
      if (id != null) 'id': id,
      'challengeId': challengeId,
      'wallet': wallet,
      'challengeXdr': challengeXdr,
      'transactionHash': transactionHash,
      'expiresAt': expiresAt.toJson(),
      'createdAt': createdAt.toJson(),
      if (consumedAt != null) 'consumedAt': consumedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WalletChallengeRecordInclude include() {
    return WalletChallengeRecordInclude._();
  }

  static WalletChallengeRecordIncludeList includeList({
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WalletChallengeRecordTable>? orderBy,
    _is.OrderByListBuilder<WalletChallengeRecordTable>? orderByList,
    WalletChallengeRecordInclude? include,
  }) {
    return WalletChallengeRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WalletChallengeRecord.t),
      orderByList: orderByList?.call(WalletChallengeRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WalletChallengeRecordImpl extends WalletChallengeRecord {
  _WalletChallengeRecordImpl({
    int? id,
    required String challengeId,
    required String wallet,
    required String challengeXdr,
    required String transactionHash,
    required DateTime expiresAt,
    required DateTime createdAt,
    DateTime? consumedAt,
  }) : super._(
         id: id,
         challengeId: challengeId,
         wallet: wallet,
         challengeXdr: challengeXdr,
         transactionHash: transactionHash,
         expiresAt: expiresAt,
         createdAt: createdAt,
         consumedAt: consumedAt,
       );

  /// Returns a shallow copy of this [WalletChallengeRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WalletChallengeRecord copyWith({
    Object? id = _Undefined,
    String? challengeId,
    String? wallet,
    String? challengeXdr,
    String? transactionHash,
    DateTime? expiresAt,
    DateTime? createdAt,
    Object? consumedAt = _Undefined,
  }) {
    return WalletChallengeRecord(
      id: id is int? ? id : this.id,
      challengeId: challengeId ?? this.challengeId,
      wallet: wallet ?? this.wallet,
      challengeXdr: challengeXdr ?? this.challengeXdr,
      transactionHash: transactionHash ?? this.transactionHash,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      consumedAt: consumedAt is DateTime? ? consumedAt : this.consumedAt,
    );
  }
}

class WalletChallengeRecordUpdateTable
    extends _is.UpdateTable<WalletChallengeRecordTable> {
  WalletChallengeRecordUpdateTable(super.table);

  _is.ColumnValue<String, String> challengeId(String value) => _is.ColumnValue(
    table.challengeId,
    value,
  );

  _is.ColumnValue<String, String> wallet(String value) => _is.ColumnValue(
    table.wallet,
    value,
  );

  _is.ColumnValue<String, String> challengeXdr(String value) => _is.ColumnValue(
    table.challengeXdr,
    value,
  );

  _is.ColumnValue<String, String> transactionHash(String value) =>
      _is.ColumnValue(
        table.transactionHash,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime value) =>
      _is.ColumnValue(
        table.expiresAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> consumedAt(DateTime? value) =>
      _is.ColumnValue(
        table.consumedAt,
        value,
      );
}

class WalletChallengeRecordTable extends _is.Table<int?> {
  WalletChallengeRecordTable({super.tableRelation})
    : super(tableName: 'wallet_challenge') {
    updateTable = WalletChallengeRecordUpdateTable(this);
    challengeId = _is.ColumnString(
      'challengeId',
      this,
    );
    wallet = _is.ColumnString(
      'wallet',
      this,
    );
    challengeXdr = _is.ColumnString(
      'challengeXdr',
      this,
    );
    transactionHash = _is.ColumnString(
      'transactionHash',
      this,
    );
    expiresAt = _is.ColumnDateTime(
      'expiresAt',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    consumedAt = _is.ColumnDateTime(
      'consumedAt',
      this,
    );
  }

  late final WalletChallengeRecordUpdateTable updateTable;

  /// Opaque id returned to the client.
  late final _is.ColumnString challengeId;

  /// Stellar G-address the challenge was issued for.
  late final _is.ColumnString wallet;

  /// Base64 unsigned server-signed challenge XDR.
  late final _is.ColumnString challengeXdr;

  /// Hex transaction hash of the challenge.
  late final _is.ColumnString transactionHash;

  /// End of the time bounds. A challenge past this instant is expired.
  late final _is.ColumnDateTime expiresAt;

  /// When the challenge was issued.
  late final _is.ColumnDateTime createdAt;

  /// Set when a verification consumes the challenge.
  late final _is.ColumnDateTime consumedAt;

  @override
  List<_is.Column> get columns => [
    id,
    challengeId,
    wallet,
    challengeXdr,
    transactionHash,
    expiresAt,
    createdAt,
    consumedAt,
  ];
}

class WalletChallengeRecordInclude extends _is.IncludeObject {
  WalletChallengeRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => WalletChallengeRecord.t;
}

class WalletChallengeRecordIncludeList extends _is.IncludeList {
  WalletChallengeRecordIncludeList._({
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WalletChallengeRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WalletChallengeRecord.t;
}

class WalletChallengeRecordRepository {
  const WalletChallengeRecordRepository._();

  /// Returns a list of [WalletChallengeRecord]s matching the given query parameters.
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
  Future<List<WalletChallengeRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WalletChallengeRecordTable>? orderBy,
    _is.OrderByListBuilder<WalletChallengeRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WalletChallengeRecord>(
      where: where?.call(WalletChallengeRecord.t),
      orderBy: orderBy?.call(WalletChallengeRecord.t),
      orderByList: orderByList?.call(WalletChallengeRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WalletChallengeRecord] matching the given query parameters.
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
  Future<WalletChallengeRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<WalletChallengeRecordTable>? orderBy,
    _is.OrderByListBuilder<WalletChallengeRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WalletChallengeRecord>(
      where: where?.call(WalletChallengeRecord.t),
      orderBy: orderBy?.call(WalletChallengeRecord.t),
      orderByList: orderByList?.call(WalletChallengeRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WalletChallengeRecord] by its [id] or null if no such row exists.
  Future<WalletChallengeRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WalletChallengeRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WalletChallengeRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [WalletChallengeRecord]s will have their `id` fields set.
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
  Future<List<WalletChallengeRecord>> insert(
    _is.DatabaseSession session,
    List<WalletChallengeRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WalletChallengeRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WalletChallengeRecord] and returns the inserted row.
  ///
  /// The returned [WalletChallengeRecord] will have its `id` field set.
  Future<WalletChallengeRecord> insertRow(
    _is.DatabaseSession session,
    WalletChallengeRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WalletChallengeRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WalletChallengeRecord]s in the list and returns the resulting rows.
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
  /// The returned [WalletChallengeRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WalletChallengeRecord>> upsert(
    _is.DatabaseSession session,
    List<WalletChallengeRecord> rows, {
    required _is.ColumnSelections<WalletChallengeRecordTable> conflictColumns,
    _is.ColumnSelections<WalletChallengeRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WalletChallengeRecord>(
      rows,
      conflictColumns: conflictColumns(WalletChallengeRecord.t),
      updateColumns: updateColumns?.call(WalletChallengeRecord.t),
      updateWhere: updateWhere?.call(WalletChallengeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WalletChallengeRecord] and returns the resulting row.
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
  /// The returned [WalletChallengeRecord] will have its `id` field set.
  Future<WalletChallengeRecord?> upsertRow(
    _is.DatabaseSession session,
    WalletChallengeRecord row, {
    required _is.ColumnSelections<WalletChallengeRecordTable> conflictColumns,
    _is.ColumnSelections<WalletChallengeRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WalletChallengeRecord>(
      row,
      conflictColumns: conflictColumns(WalletChallengeRecord.t),
      updateColumns: updateColumns?.call(WalletChallengeRecord.t),
      updateWhere: updateWhere?.call(WalletChallengeRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [WalletChallengeRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WalletChallengeRecord>> update(
    _is.DatabaseSession session,
    List<WalletChallengeRecord> rows, {
    _is.ColumnSelections<WalletChallengeRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WalletChallengeRecord>(
      rows,
      columns: columns?.call(WalletChallengeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WalletChallengeRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WalletChallengeRecord> updateRow(
    _is.DatabaseSession session,
    WalletChallengeRecord row, {
    _is.ColumnSelections<WalletChallengeRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WalletChallengeRecord>(
      row,
      columns: columns?.call(WalletChallengeRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WalletChallengeRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WalletChallengeRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WalletChallengeRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WalletChallengeRecord>(
      id,
      columnValues: columnValues(WalletChallengeRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WalletChallengeRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WalletChallengeRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WalletChallengeRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<WalletChallengeRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WalletChallengeRecordTable>? orderBy,
    _is.OrderByListBuilder<WalletChallengeRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WalletChallengeRecord>(
      columnValues: columnValues(WalletChallengeRecord.t.updateTable),
      where: where(WalletChallengeRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WalletChallengeRecord.t),
      orderByList: orderByList?.call(WalletChallengeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WalletChallengeRecord]s in the list and returns the deleted rows.
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
  Future<List<WalletChallengeRecord>> delete(
    _is.DatabaseSession session,
    List<WalletChallengeRecord> rows, {
    _is.OrderByBuilder<WalletChallengeRecordTable>? orderBy,
    _is.OrderByListBuilder<WalletChallengeRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WalletChallengeRecord>(
      rows,
      orderBy: orderBy?.call(WalletChallengeRecord.t),
      orderByList: orderByList?.call(WalletChallengeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WalletChallengeRecord].
  Future<WalletChallengeRecord> deleteRow(
    _is.DatabaseSession session,
    WalletChallengeRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WalletChallengeRecord>(
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
  Future<List<WalletChallengeRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WalletChallengeRecordTable> where,
    _is.OrderByBuilder<WalletChallengeRecordTable>? orderBy,
    _is.OrderByListBuilder<WalletChallengeRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WalletChallengeRecord>(
      where: where(WalletChallengeRecord.t),
      orderBy: orderBy?.call(WalletChallengeRecord.t),
      orderByList: orderByList?.call(WalletChallengeRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WalletChallengeRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WalletChallengeRecord>(
      where: where?.call(WalletChallengeRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WalletChallengeRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WalletChallengeRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WalletChallengeRecord>(
      where: where(WalletChallengeRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
