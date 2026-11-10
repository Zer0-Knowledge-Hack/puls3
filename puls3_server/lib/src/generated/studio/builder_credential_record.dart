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

/// A builder's provider credential (#235), so test runs and paid hires of a
/// Studio agent keep working after a server restart. The secret is never
/// stored in plain text: it is encrypted with AES-256-GCM under the custody
/// key, like `agent_wallet`, and bound to its owner and provider as GCM
/// additional data. Server-only: the secret never crosses an endpoint.
abstract class BuilderCredentialRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BuilderCredentialRecord._({
    this.id,
    required this.owner,
    required this.provider,
    this.accountId,
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.keyVersion,
    required this.updatedAt,
  });

  factory BuilderCredentialRecord({
    int? id,
    required String owner,
    required String provider,
    String? accountId,
    required String ciphertext,
    required String nonce,
    required String mac,
    required int keyVersion,
    required DateTime updatedAt,
  }) = _BuilderCredentialRecordImpl;

  factory BuilderCredentialRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BuilderCredentialRecord(
      id: jsonSerialization['id'] as int?,
      owner: jsonSerialization['owner'] as String,
      provider: jsonSerialization['provider'] as String,
      accountId: jsonSerialization['accountId'] as String?,
      ciphertext: jsonSerialization['ciphertext'] as String,
      nonce: jsonSerialization['nonce'] as String,
      mac: jsonSerialization['mac'] as String,
      keyVersion: jsonSerialization['keyVersion'] as int,
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = BuilderCredentialRecordTable();

  static const db = BuilderCredentialRecordRepository._();

  @override
  int? id;

  /// The builder wallet that saved it (a G… address).
  String owner;

  /// `workers-ai` or a paid provider such as `anthropic`.
  String provider;

  /// The Cloudflare account id for `workers-ai`. Not a secret.
  String? accountId;

  /// Base64 AES-256-GCM ciphertext of the token or key.
  String ciphertext;

  /// Base64 GCM nonce.
  String nonce;

  /// Base64 GCM authentication tag.
  String mac;

  /// The cipher key version, so the key can be rotated.
  int keyVersion;

  /// When the builder last saved it.
  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BuilderCredentialRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BuilderCredentialRecord copyWith({
    int? id,
    String? owner,
    String? provider,
    String? accountId,
    String? ciphertext,
    String? nonce,
    String? mac,
    int? keyVersion,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BuilderCredentialRecord',
      if (id != null) 'id': id,
      'owner': owner,
      'provider': provider,
      if (accountId != null) 'accountId': accountId,
      'ciphertext': ciphertext,
      'nonce': nonce,
      'mac': mac,
      'keyVersion': keyVersion,
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BuilderCredentialRecordInclude include() {
    return BuilderCredentialRecordInclude._();
  }

  static BuilderCredentialRecordIncludeList includeList({
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BuilderCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<BuilderCredentialRecordTable>? orderByList,
    BuilderCredentialRecordInclude? include,
  }) {
    return BuilderCredentialRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BuilderCredentialRecord.t),
      orderByList: orderByList?.call(BuilderCredentialRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BuilderCredentialRecordImpl extends BuilderCredentialRecord {
  _BuilderCredentialRecordImpl({
    int? id,
    required String owner,
    required String provider,
    String? accountId,
    required String ciphertext,
    required String nonce,
    required String mac,
    required int keyVersion,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         owner: owner,
         provider: provider,
         accountId: accountId,
         ciphertext: ciphertext,
         nonce: nonce,
         mac: mac,
         keyVersion: keyVersion,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [BuilderCredentialRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BuilderCredentialRecord copyWith({
    Object? id = _Undefined,
    String? owner,
    String? provider,
    Object? accountId = _Undefined,
    String? ciphertext,
    String? nonce,
    String? mac,
    int? keyVersion,
    DateTime? updatedAt,
  }) {
    return BuilderCredentialRecord(
      id: id is int? ? id : this.id,
      owner: owner ?? this.owner,
      provider: provider ?? this.provider,
      accountId: accountId is String? ? accountId : this.accountId,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      mac: mac ?? this.mac,
      keyVersion: keyVersion ?? this.keyVersion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BuilderCredentialRecordUpdateTable
    extends _is.UpdateTable<BuilderCredentialRecordTable> {
  BuilderCredentialRecordUpdateTable(super.table);

  _is.ColumnValue<String, String> owner(String value) => _is.ColumnValue(
    table.owner,
    value,
  );

  _is.ColumnValue<String, String> provider(String value) => _is.ColumnValue(
    table.provider,
    value,
  );

  _is.ColumnValue<String, String> accountId(String? value) => _is.ColumnValue(
    table.accountId,
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

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class BuilderCredentialRecordTable extends _is.Table<int?> {
  BuilderCredentialRecordTable({super.tableRelation})
    : super(tableName: 'builder_credential') {
    updateTable = BuilderCredentialRecordUpdateTable(this);
    owner = _is.ColumnString(
      'owner',
      this,
    );
    provider = _is.ColumnString(
      'provider',
      this,
    );
    accountId = _is.ColumnString(
      'accountId',
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
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final BuilderCredentialRecordUpdateTable updateTable;

  /// The builder wallet that saved it (a G… address).
  late final _is.ColumnString owner;

  /// `workers-ai` or a paid provider such as `anthropic`.
  late final _is.ColumnString provider;

  /// The Cloudflare account id for `workers-ai`. Not a secret.
  late final _is.ColumnString accountId;

  /// Base64 AES-256-GCM ciphertext of the token or key.
  late final _is.ColumnString ciphertext;

  /// Base64 GCM nonce.
  late final _is.ColumnString nonce;

  /// Base64 GCM authentication tag.
  late final _is.ColumnString mac;

  /// The cipher key version, so the key can be rotated.
  late final _is.ColumnInt keyVersion;

  /// When the builder last saved it.
  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    owner,
    provider,
    accountId,
    ciphertext,
    nonce,
    mac,
    keyVersion,
    updatedAt,
  ];
}

class BuilderCredentialRecordInclude extends _is.IncludeObject {
  BuilderCredentialRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BuilderCredentialRecord.t;
}

class BuilderCredentialRecordIncludeList extends _is.IncludeList {
  BuilderCredentialRecordIncludeList._({
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BuilderCredentialRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BuilderCredentialRecord.t;
}

class BuilderCredentialRecordRepository {
  const BuilderCredentialRecordRepository._();

  /// Returns a list of [BuilderCredentialRecord]s matching the given query parameters.
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
  Future<List<BuilderCredentialRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BuilderCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<BuilderCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BuilderCredentialRecord>(
      where: where?.call(BuilderCredentialRecord.t),
      orderBy: orderBy?.call(BuilderCredentialRecord.t),
      orderByList: orderByList?.call(BuilderCredentialRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [BuilderCredentialRecord] matching the given query parameters.
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
  Future<BuilderCredentialRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<BuilderCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<BuilderCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BuilderCredentialRecord>(
      where: where?.call(BuilderCredentialRecord.t),
      orderBy: orderBy?.call(BuilderCredentialRecord.t),
      orderByList: orderByList?.call(BuilderCredentialRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BuilderCredentialRecord] by its [id] or null if no such row exists.
  Future<BuilderCredentialRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BuilderCredentialRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BuilderCredentialRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [BuilderCredentialRecord]s will have their `id` fields set.
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
  Future<List<BuilderCredentialRecord>> insert(
    _is.DatabaseSession session,
    List<BuilderCredentialRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BuilderCredentialRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BuilderCredentialRecord] and returns the inserted row.
  ///
  /// The returned [BuilderCredentialRecord] will have its `id` field set.
  Future<BuilderCredentialRecord> insertRow(
    _is.DatabaseSession session,
    BuilderCredentialRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BuilderCredentialRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BuilderCredentialRecord]s in the list and returns the resulting rows.
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
  /// The returned [BuilderCredentialRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BuilderCredentialRecord>> upsert(
    _is.DatabaseSession session,
    List<BuilderCredentialRecord> rows, {
    required _is.ColumnSelections<BuilderCredentialRecordTable> conflictColumns,
    _is.ColumnSelections<BuilderCredentialRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BuilderCredentialRecord>(
      rows,
      conflictColumns: conflictColumns(BuilderCredentialRecord.t),
      updateColumns: updateColumns?.call(BuilderCredentialRecord.t),
      updateWhere: updateWhere?.call(BuilderCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BuilderCredentialRecord] and returns the resulting row.
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
  /// The returned [BuilderCredentialRecord] will have its `id` field set.
  Future<BuilderCredentialRecord?> upsertRow(
    _is.DatabaseSession session,
    BuilderCredentialRecord row, {
    required _is.ColumnSelections<BuilderCredentialRecordTable> conflictColumns,
    _is.ColumnSelections<BuilderCredentialRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BuilderCredentialRecord>(
      row,
      conflictColumns: conflictColumns(BuilderCredentialRecord.t),
      updateColumns: updateColumns?.call(BuilderCredentialRecord.t),
      updateWhere: updateWhere?.call(BuilderCredentialRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [BuilderCredentialRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BuilderCredentialRecord>> update(
    _is.DatabaseSession session,
    List<BuilderCredentialRecord> rows, {
    _is.ColumnSelections<BuilderCredentialRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BuilderCredentialRecord>(
      rows,
      columns: columns?.call(BuilderCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BuilderCredentialRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BuilderCredentialRecord> updateRow(
    _is.DatabaseSession session,
    BuilderCredentialRecord row, {
    _is.ColumnSelections<BuilderCredentialRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BuilderCredentialRecord>(
      row,
      columns: columns?.call(BuilderCredentialRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BuilderCredentialRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BuilderCredentialRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BuilderCredentialRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BuilderCredentialRecord>(
      id,
      columnValues: columnValues(BuilderCredentialRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BuilderCredentialRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BuilderCredentialRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BuilderCredentialRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BuilderCredentialRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BuilderCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<BuilderCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BuilderCredentialRecord>(
      columnValues: columnValues(BuilderCredentialRecord.t.updateTable),
      where: where(BuilderCredentialRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BuilderCredentialRecord.t),
      orderByList: orderByList?.call(BuilderCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BuilderCredentialRecord]s in the list and returns the deleted rows.
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
  Future<List<BuilderCredentialRecord>> delete(
    _is.DatabaseSession session,
    List<BuilderCredentialRecord> rows, {
    _is.OrderByBuilder<BuilderCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<BuilderCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BuilderCredentialRecord>(
      rows,
      orderBy: orderBy?.call(BuilderCredentialRecord.t),
      orderByList: orderByList?.call(BuilderCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BuilderCredentialRecord].
  Future<BuilderCredentialRecord> deleteRow(
    _is.DatabaseSession session,
    BuilderCredentialRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BuilderCredentialRecord>(
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
  Future<List<BuilderCredentialRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BuilderCredentialRecordTable> where,
    _is.OrderByBuilder<BuilderCredentialRecordTable>? orderBy,
    _is.OrderByListBuilder<BuilderCredentialRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BuilderCredentialRecord>(
      where: where(BuilderCredentialRecord.t),
      orderBy: orderBy?.call(BuilderCredentialRecord.t),
      orderByList: orderByList?.call(BuilderCredentialRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BuilderCredentialRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BuilderCredentialRecord>(
      where: where?.call(BuilderCredentialRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BuilderCredentialRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BuilderCredentialRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BuilderCredentialRecord>(
      where: where(BuilderCredentialRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
