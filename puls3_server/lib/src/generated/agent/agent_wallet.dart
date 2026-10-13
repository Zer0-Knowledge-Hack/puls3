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

/// A custodied agent wallet (ADR-0003 decision 4). The secret is never stored
/// in plain text: it is encrypted with AES-256-GCM and the row keeps only the
/// ciphertext, nonce, MAC and key version. Server-only: the secret never crosses
/// an endpoint.
abstract class AgentWallet
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AgentWallet._({
    this.id,
    required this.owner,
    required this.address,
    required this.idempotencyKey,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.keyVersion,
    this.agentId,
    required this.createdAt,
  });

  factory AgentWallet({
    int? id,
    required String owner,
    required String address,
    required String idempotencyKey,
    required String ciphertext,
    required String nonce,
    required String mac,
    required int keyVersion,
    int? agentId,
    required DateTime createdAt,
  }) = _AgentWalletImpl;

  factory AgentWallet.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentWallet(
      id: jsonSerialization['id'] as int?,
      owner: jsonSerialization['owner'] as String,
      address: jsonSerialization['address'] as String,
      idempotencyKey: jsonSerialization['idempotencyKey'] as String,
      ciphertext: jsonSerialization['ciphertext'] as String,
      nonce: jsonSerialization['nonce'] as String,
      mac: jsonSerialization['mac'] as String,
      keyVersion: jsonSerialization['keyVersion'] as int,
      agentId: jsonSerialization['agentId'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = AgentWalletTable();

  static const db = AgentWalletRepository._();

  @override
  int? id;

  /// The builder that owns the agent; the only address allowed to control it.
  String owner;

  /// The agent's payment account, a G… address.
  String address;

  /// The caller's idempotency key (the deploy session/draft id). Creating a
  /// wallet twice with the same key returns the same wallet.
  String idempotencyKey;

  /// Base64 AES-256-GCM ciphertext of the secret seed. The wallet address is
  /// the GCM additional authenticated data, binding the secret to its row.
  String ciphertext;

  /// Base64 GCM nonce.
  String nonce;

  /// Base64 GCM authentication tag.
  String mac;

  /// The cipher key version, so a key can be rotated later.
  int keyVersion;

  /// The on-chain registry id, set once `register_full` is confirmed.
  int? agentId;

  /// When the wallet was created.
  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentWallet]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AgentWallet copyWith({
    int? id,
    String? owner,
    String? address,
    String? idempotencyKey,
    String? ciphertext,
    String? nonce,
    String? mac,
    int? keyVersion,
    int? agentId,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentWallet',
      if (id != null) 'id': id,
      'owner': owner,
      'address': address,
      'idempotencyKey': idempotencyKey,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'mac': mac,
      'keyVersion': keyVersion,
      if (agentId != null) 'agentId': agentId,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AgentWalletInclude include() {
    return AgentWalletInclude._();
  }

  static AgentWalletIncludeList includeList({
    _is.WhereExpressionBuilder<AgentWalletTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AgentWalletTable>? orderBy,
    _is.OrderByListBuilder<AgentWalletTable>? orderByList,
    AgentWalletInclude? include,
  }) {
    return AgentWalletIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentWallet.t),
      orderByList: orderByList?.call(AgentWallet.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentWalletImpl extends AgentWallet {
  _AgentWalletImpl({
    int? id,
    required String owner,
    required String address,
    required String idempotencyKey,
    required String ciphertext,
    required String nonce,
    required String mac,
    required int keyVersion,
    int? agentId,
    required DateTime createdAt,
  }) : super._(
         id: id,
         owner: owner,
         address: address,
         idempotencyKey: idempotencyKey,
         ciphertext: ciphertext,
         nonce: nonce,
         mac: mac,
         keyVersion: keyVersion,
         agentId: agentId,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AgentWallet]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AgentWallet copyWith({
    Object? id = _Undefined,
    String? owner,
    String? address,
    String? idempotencyKey,
    String? ciphertext,
    String? nonce,
    String? mac,
    int? keyVersion,
    Object? agentId = _Undefined,
    DateTime? createdAt,
  }) {
    return AgentWallet(
      id: id is int? ? id : this.id,
      owner: owner ?? this.owner,
      address: address ?? this.address,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      keyVersion: keyVersion ?? this.keyVersion,
      agentId: agentId is int? ? agentId : this.agentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AgentWalletUpdateTable extends _is.UpdateTable<AgentWalletTable> {
  AgentWalletUpdateTable(super.table);

  _is.ColumnValue<String, String> owner(String value) => _is.ColumnValue(
    table.owner,
    value,
  );

  _is.ColumnValue<String, String> address(String value) => _is.ColumnValue(
    table.address,
    value,
  );

  _is.ColumnValue<String, String> idempotencyKey(String value) =>
      _is.ColumnValue(
        table.idempotencyKey,
        value,
      );

  _is.ColumnValue<String, String> ciphertext(String value) => _is.ColumnValue(
    table.ciphertext,
    value,
  );

  _is.ColumnValue<String, String> nonce(String value) => _is.ColumnValue(
    table.nonce,
    value,
  );

  _is.ColumnValue<String, String> mac(String value) => _is.ColumnValue(
    table.mac,
    value,
  );

  _is.ColumnValue<int, int> keyVersion(int value) => _is.ColumnValue(
    table.keyVersion,
    value,
  );

  _is.ColumnValue<int, int> agentId(int? value) => _is.ColumnValue(
    table.agentId,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class AgentWalletTable extends _is.Table<int?> {
  AgentWalletTable({super.tableRelation}) : super(tableName: 'agent_wallet') {
    updateTable = AgentWalletUpdateTable(this);
    owner = _is.ColumnString(
      'owner',
      this,
    );
    address = _is.ColumnString(
      'address',
      this,
    );
    idempotencyKey = _is.ColumnString(
      'idempotencyKey',
      this,
    );
    ciphertext = _is.ColumnString(
      'ciphertext',
      this,
    );
    nonce = _is.ColumnString(
      'nonce',
      this,
    );
    mac = _is.ColumnString(
      'mac',
      this,
    );
    keyVersion = _is.ColumnInt(
      'keyVersion',
      this,
    );
    agentId = _is.ColumnInt(
      'agentId',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final AgentWalletUpdateTable updateTable;

  /// The builder that owns the agent; the only address allowed to control it.
  late final _is.ColumnString owner;

  /// The agent's payment account, a G… address.
  late final _is.ColumnString address;

  /// The caller's idempotency key (the deploy session/draft id). Creating a
  /// wallet twice with the same key returns the same wallet.
  late final _is.ColumnString idempotencyKey;

  /// Base64 AES-256-GCM ciphertext of the secret seed. The wallet address is
  /// the GCM additional authenticated data, binding the secret to its row.
  late final _is.ColumnString ciphertext;

  /// Base64 GCM nonce.
  late final _is.ColumnString nonce;

  /// Base64 GCM authentication tag.
  late final _is.ColumnString mac;

  /// The cipher key version, so a key can be rotated later.
  late final _is.ColumnInt keyVersion;

  /// The on-chain registry id, set once `register_full` is confirmed.
  late final _is.ColumnInt agentId;

  /// When the wallet was created.
  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    owner,
    address,
    idempotencyKey,
    ciphertext,
    nonce,
    mac,
    keyVersion,
    agentId,
    createdAt,
  ];
}

class AgentWalletInclude extends _is.IncludeObject {
  AgentWalletInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AgentWallet.t;
}

class AgentWalletIncludeList extends _is.IncludeList {
  AgentWalletIncludeList._({
    _is.WhereExpressionBuilder<AgentWalletTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentWallet.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AgentWallet.t;
}

class AgentWalletRepository {
  const AgentWalletRepository._();

  /// Returns a list of [AgentWallet]s matching the given query parameters.
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
  Future<List<AgentWallet>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AgentWalletTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AgentWalletTable>? orderBy,
    _is.OrderByListBuilder<AgentWalletTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AgentWallet>(
      where: where?.call(AgentWallet.t),
      orderBy: orderBy?.call(AgentWallet.t),
      orderByList: orderByList?.call(AgentWallet.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AgentWallet] matching the given query parameters.
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
  Future<AgentWallet?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AgentWalletTable>? where,
    int? offset,
    _is.OrderByBuilder<AgentWalletTable>? orderBy,
    _is.OrderByListBuilder<AgentWalletTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AgentWallet>(
      where: where?.call(AgentWallet.t),
      orderBy: orderBy?.call(AgentWallet.t),
      orderByList: orderByList?.call(AgentWallet.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AgentWallet] by its [id] or null if no such row exists.
  Future<AgentWallet?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AgentWallet>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AgentWallet]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentWallet]s will have their `id` fields set.
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
  Future<List<AgentWallet>> insert(
    _is.DatabaseSession session,
    List<AgentWallet> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AgentWallet>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AgentWallet] and returns the inserted row.
  ///
  /// The returned [AgentWallet] will have its `id` field set.
  Future<AgentWallet> insertRow(
    _is.DatabaseSession session,
    AgentWallet row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentWallet>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AgentWallet]s in the list and returns the resulting rows.
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
  /// The returned [AgentWallet]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AgentWallet>> upsert(
    _is.DatabaseSession session,
    List<AgentWallet> rows, {
    required _is.ColumnSelections<AgentWalletTable> conflictColumns,
    _is.ColumnSelections<AgentWalletTable>? updateColumns,
    _is.WhereExpressionBuilder<AgentWalletTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AgentWallet>(
      rows,
      conflictColumns: conflictColumns(AgentWallet.t),
      updateColumns: updateColumns?.call(AgentWallet.t),
      updateWhere: updateWhere?.call(AgentWallet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AgentWallet] and returns the resulting row.
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
  /// The returned [AgentWallet] will have its `id` field set.
  Future<AgentWallet?> upsertRow(
    _is.DatabaseSession session,
    AgentWallet row, {
    required _is.ColumnSelections<AgentWalletTable> conflictColumns,
    _is.ColumnSelections<AgentWalletTable>? updateColumns,
    _is.WhereExpressionBuilder<AgentWalletTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AgentWallet>(
      row,
      conflictColumns: conflictColumns(AgentWallet.t),
      updateColumns: updateColumns?.call(AgentWallet.t),
      updateWhere: updateWhere?.call(AgentWallet.t),
      transaction: transaction,
    );
  }

  /// Updates all [AgentWallet]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AgentWallet>> update(
    _is.DatabaseSession session,
    List<AgentWallet> rows, {
    _is.ColumnSelections<AgentWalletTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AgentWallet>(
      rows,
      columns: columns?.call(AgentWallet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AgentWallet]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentWallet> updateRow(
    _is.DatabaseSession session,
    AgentWallet row, {
    _is.ColumnSelections<AgentWalletTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentWallet>(
      row,
      columns: columns?.call(AgentWallet.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentWallet] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentWallet?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AgentWalletUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentWallet>(
      id,
      columnValues: columnValues(AgentWallet.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentWallet]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AgentWallet>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AgentWalletUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AgentWalletTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AgentWalletTable>? orderBy,
    _is.OrderByListBuilder<AgentWalletTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AgentWallet>(
      columnValues: columnValues(AgentWallet.t.updateTable),
      where: where(AgentWallet.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentWallet.t),
      orderByList: orderByList?.call(AgentWallet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AgentWallet]s in the list and returns the deleted rows.
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
  Future<List<AgentWallet>> delete(
    _is.DatabaseSession session,
    List<AgentWallet> rows, {
    _is.OrderByBuilder<AgentWalletTable>? orderBy,
    _is.OrderByListBuilder<AgentWalletTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AgentWallet>(
      rows,
      orderBy: orderBy?.call(AgentWallet.t),
      orderByList: orderByList?.call(AgentWallet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AgentWallet].
  Future<AgentWallet> deleteRow(
    _is.DatabaseSession session,
    AgentWallet row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentWallet>(
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
  Future<List<AgentWallet>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AgentWalletTable> where,
    _is.OrderByBuilder<AgentWalletTable>? orderBy,
    _is.OrderByListBuilder<AgentWalletTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AgentWallet>(
      where: where(AgentWallet.t),
      orderBy: orderBy?.call(AgentWallet.t),
      orderByList: orderByList?.call(AgentWallet.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AgentWalletTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AgentWallet>(
      where: where?.call(AgentWallet.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AgentWallet] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AgentWalletTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AgentWallet>(
      where: where(AgentWallet.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
