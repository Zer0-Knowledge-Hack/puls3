/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:puls3_server/src/generated/protocol.dart' as _i7k47pdw;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;

/// Maps one Stellar wallet to one Serverpod auth user. Server-only.
abstract class WalletAccount
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  WalletAccount._({
    this.id,
    required this.wallet,
    required this.authUserId,
    this.authUser,
    required this.createdAt,
  });

  factory WalletAccount({
    int? id,
    required String wallet,
    required _is.UuidValue authUserId,
    _iacs.AuthUser? authUser,
    required DateTime createdAt,
  }) = _WalletAccountImpl;

  factory WalletAccount.fromJson(Map<String, dynamic> jsonSerialization) {
    return WalletAccount(
      id: jsonSerialization['id'] as int?,
      wallet: jsonSerialization['wallet'] as String,
      authUserId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['authUserId'],
      ),
      authUser: jsonSerialization['authUser'] == null
          ? null
          : _i7k47pdw.Protocol().deserialize<_iacs.AuthUser>(
              jsonSerialization['authUser'],
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = WalletAccountTable();

  static const db = WalletAccountRepository._();

  @override
  int? id;

  /// Stellar G-address. One row per wallet.
  String wallet;

  _is.UuidValue authUserId;

  /// The auth user this wallet signs in as.
  ///
  /// Serverpod 4.0.4 requires a model relation to be nullable. WalletIdp
  /// always sets it; the unique index keeps one user per row.
  _iacs.AuthUser? authUser;

  /// When the mapping was created.
  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [WalletAccount]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  WalletAccount copyWith({
    int? id,
    String? wallet,
    _is.UuidValue? authUserId,
    _iacs.AuthUser? authUser,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'WalletAccount',
      if (id != null) 'id': id,
      'wallet': wallet,
      'authUserId': authUserId.toJson(),
      if (authUser != null) 'authUser': authUser?.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static WalletAccountInclude include({_iacs.AuthUserInclude? authUser}) {
    return WalletAccountInclude._(authUser: authUser);
  }

  static WalletAccountIncludeList includeList({
    _is.WhereExpressionBuilder<WalletAccountTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WalletAccountTable>? orderBy,
    _is.OrderByListBuilder<WalletAccountTable>? orderByList,
    WalletAccountInclude? include,
  }) {
    return WalletAccountIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WalletAccount.t),
      orderByList: orderByList?.call(WalletAccount.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _WalletAccountImpl extends WalletAccount {
  _WalletAccountImpl({
    int? id,
    required String wallet,
    required _is.UuidValue authUserId,
    _iacs.AuthUser? authUser,
    required DateTime createdAt,
  }) : super._(
         id: id,
         wallet: wallet,
         authUserId: authUserId,
         authUser: authUser,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [WalletAccount]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  WalletAccount copyWith({
    Object? id = _Undefined,
    String? wallet,
    _is.UuidValue? authUserId,
    Object? authUser = _Undefined,
    DateTime? createdAt,
  }) {
    return WalletAccount(
      id: id is int? ? id : this.id,
      wallet: wallet ?? this.wallet,
      authUserId: authUserId ?? this.authUserId,
      authUser: authUser is _iacs.AuthUser?
          ? authUser
          : this.authUser?.copyWith(),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WalletAccountUpdateTable extends _is.UpdateTable<WalletAccountTable> {
  WalletAccountUpdateTable(super.table);

  _is.ColumnValue<String, String> wallet(String value) => _is.ColumnValue(
    table.wallet,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> authUserId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.authUserId,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class WalletAccountTable extends _is.Table<int?> {
  WalletAccountTable({super.tableRelation})
    : super(tableName: 'wallet_account') {
    updateTable = WalletAccountUpdateTable(this);
    wallet = _is.ColumnString(
      'wallet',
      this,
    );
    authUserId = _is.ColumnUuid(
      'authUserId',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final WalletAccountUpdateTable updateTable;

  /// Stellar G-address. One row per wallet.
  late final _is.ColumnString wallet;

  late final _is.ColumnUuid authUserId;

  /// The auth user this wallet signs in as.
  ///
  /// Serverpod 4.0.4 requires a model relation to be nullable. WalletIdp
  /// always sets it; the unique index keeps one user per row.
  _iacs.AuthUserTable? _authUser;

  /// When the mapping was created.
  late final _is.ColumnDateTime createdAt;

  _iacs.AuthUserTable get authUser {
    if (_authUser != null) return _authUser!;
    _authUser = _is.createRelationTable(
      relationFieldName: 'authUser',
      field: WalletAccount.t.authUserId,
      foreignField: _iacs.AuthUser.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iacs.AuthUserTable(tableRelation: foreignTableRelation),
    );
    return _authUser!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    wallet,
    authUserId,
    createdAt,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'authUser') {
      return authUser;
    }
    return null;
  }
}

class WalletAccountInclude extends _is.IncludeObject {
  WalletAccountInclude._({_iacs.AuthUserInclude? authUser}) {
    _authUser = authUser;
  }

  _iacs.AuthUserInclude? _authUser;

  @override
  Map<String, _is.Include?> get includes => {'authUser': _authUser};

  @override
  _is.Table<int?> get table => WalletAccount.t;
}

class WalletAccountIncludeList extends _is.IncludeList {
  WalletAccountIncludeList._({
    _is.WhereExpressionBuilder<WalletAccountTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(WalletAccount.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => WalletAccount.t;
}

class WalletAccountRepository {
  const WalletAccountRepository._();

  final attachRow = const WalletAccountAttachRowRepository._();

  /// Returns a list of [WalletAccount]s matching the given query parameters.
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
  Future<List<WalletAccount>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WalletAccountTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WalletAccountTable>? orderBy,
    _is.OrderByListBuilder<WalletAccountTable>? orderByList,
    _is.Transaction? transaction,
    WalletAccountInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<WalletAccount>(
      where: where?.call(WalletAccount.t),
      orderBy: orderBy?.call(WalletAccount.t),
      orderByList: orderByList?.call(WalletAccount.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [WalletAccount] matching the given query parameters.
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
  Future<WalletAccount?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WalletAccountTable>? where,
    int? offset,
    _is.OrderByBuilder<WalletAccountTable>? orderBy,
    _is.OrderByListBuilder<WalletAccountTable>? orderByList,
    _is.Transaction? transaction,
    WalletAccountInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<WalletAccount>(
      where: where?.call(WalletAccount.t),
      orderBy: orderBy?.call(WalletAccount.t),
      orderByList: orderByList?.call(WalletAccount.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [WalletAccount] by its [id] or null if no such row exists.
  Future<WalletAccount?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    WalletAccountInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<WalletAccount>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [WalletAccount]s in the list and returns the inserted rows.
  ///
  /// The returned [WalletAccount]s will have their `id` fields set.
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
  Future<List<WalletAccount>> insert(
    _is.DatabaseSession session,
    List<WalletAccount> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<WalletAccount>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [WalletAccount] and returns the inserted row.
  ///
  /// The returned [WalletAccount] will have its `id` field set.
  Future<WalletAccount> insertRow(
    _is.DatabaseSession session,
    WalletAccount row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<WalletAccount>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [WalletAccount]s in the list and returns the resulting rows.
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
  /// The returned [WalletAccount]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WalletAccount>> upsert(
    _is.DatabaseSession session,
    List<WalletAccount> rows, {
    required _is.ColumnSelections<WalletAccountTable> conflictColumns,
    _is.ColumnSelections<WalletAccountTable>? updateColumns,
    _is.WhereExpressionBuilder<WalletAccountTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<WalletAccount>(
      rows,
      conflictColumns: conflictColumns(WalletAccount.t),
      updateColumns: updateColumns?.call(WalletAccount.t),
      updateWhere: updateWhere?.call(WalletAccount.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [WalletAccount] and returns the resulting row.
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
  /// The returned [WalletAccount] will have its `id` field set.
  Future<WalletAccount?> upsertRow(
    _is.DatabaseSession session,
    WalletAccount row, {
    required _is.ColumnSelections<WalletAccountTable> conflictColumns,
    _is.ColumnSelections<WalletAccountTable>? updateColumns,
    _is.WhereExpressionBuilder<WalletAccountTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<WalletAccount>(
      row,
      conflictColumns: conflictColumns(WalletAccount.t),
      updateColumns: updateColumns?.call(WalletAccount.t),
      updateWhere: updateWhere?.call(WalletAccount.t),
      transaction: transaction,
    );
  }

  /// Updates all [WalletAccount]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WalletAccount>> update(
    _is.DatabaseSession session,
    List<WalletAccount> rows, {
    _is.ColumnSelections<WalletAccountTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<WalletAccount>(
      rows,
      columns: columns?.call(WalletAccount.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [WalletAccount]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<WalletAccount> updateRow(
    _is.DatabaseSession session,
    WalletAccount row, {
    _is.ColumnSelections<WalletAccountTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<WalletAccount>(
      row,
      columns: columns?.call(WalletAccount.t),
      transaction: transaction,
    );
  }

  /// Updates a single [WalletAccount] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<WalletAccount?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<WalletAccountUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<WalletAccount>(
      id,
      columnValues: columnValues(WalletAccount.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [WalletAccount]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<WalletAccount>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<WalletAccountUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<WalletAccountTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<WalletAccountTable>? orderBy,
    _is.OrderByListBuilder<WalletAccountTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<WalletAccount>(
      columnValues: columnValues(WalletAccount.t.updateTable),
      where: where(WalletAccount.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(WalletAccount.t),
      orderByList: orderByList?.call(WalletAccount.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [WalletAccount]s in the list and returns the deleted rows.
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
  Future<List<WalletAccount>> delete(
    _is.DatabaseSession session,
    List<WalletAccount> rows, {
    _is.OrderByBuilder<WalletAccountTable>? orderBy,
    _is.OrderByListBuilder<WalletAccountTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<WalletAccount>(
      rows,
      orderBy: orderBy?.call(WalletAccount.t),
      orderByList: orderByList?.call(WalletAccount.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [WalletAccount].
  Future<WalletAccount> deleteRow(
    _is.DatabaseSession session,
    WalletAccount row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<WalletAccount>(
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
  Future<List<WalletAccount>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WalletAccountTable> where,
    _is.OrderByBuilder<WalletAccountTable>? orderBy,
    _is.OrderByListBuilder<WalletAccountTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<WalletAccount>(
      where: where(WalletAccount.t),
      orderBy: orderBy?.call(WalletAccount.t),
      orderByList: orderByList?.call(WalletAccount.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<WalletAccountTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<WalletAccount>(
      where: where?.call(WalletAccount.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [WalletAccount] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<WalletAccountTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<WalletAccount>(
      where: where(WalletAccount.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class WalletAccountAttachRowRepository {
  const WalletAccountAttachRowRepository._();

  /// Creates a relation between the given [WalletAccount] and [AuthUser]
  /// by setting the [WalletAccount]'s foreign key `authUserId` to refer to the [AuthUser].
  Future<void> authUser(
    _is.DatabaseSession session,
    WalletAccount walletAccount,
    _iacs.AuthUser authUser, {
    _is.Transaction? transaction,
  }) async {
    if (walletAccount.id == null) {
      throw ArgumentError.notNull('walletAccount.id');
    }
    if (authUser.id == null) {
      throw ArgumentError.notNull('authUser.id');
    }

    var $walletAccount = walletAccount.copyWith(authUserId: authUser.id);
    await session.db.updateRow<WalletAccount>(
      $walletAccount,
      columns: [WalletAccount.t.authUserId],
      transaction: transaction,
    );
  }
}
