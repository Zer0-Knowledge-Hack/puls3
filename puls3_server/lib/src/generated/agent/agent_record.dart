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
import 'package:puls3_server/src/generated/protocol.dart' as _i7k47pdw;
import 'package:serverpod/serverpod.dart' as _is;

/// One agent of the catalog index, synced from the on-chain identity
/// registry (ADR-0001 §2: the server indexes on-chain data for the catalog).
/// Rows are complete: the indexer only stores an agent whose required
/// metadata is valid, exactly like the on-chain catalog.
abstract class AgentRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AgentRecord._({
    this.id,
    required this.registryId,
    required this.agentId,
    required this.name,
    required this.description,
    required this.skills,
    required this.priceUsdcStroops,
    this.wallet,
    this.model,
  });

  factory AgentRecord({
    int? id,
    required int registryId,
    required String agentId,
    required String name,
    required String description,
    required List<String> skills,
    required int priceUsdcStroops,
    String? wallet,
    String? model,
  }) = _AgentRecordImpl;

  factory AgentRecord.fromJson(Map<String, dynamic> jsonSerialization) {
    return AgentRecord(
      id: jsonSerialization['id'] as int?,
      registryId: jsonSerialization['registryId'] as int,
      agentId: jsonSerialization['agentId'] as String,
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String,
      skills: _i7k47pdw.Protocol().deserialize<List<String>>(
        jsonSerialization['skills'],
      ),
      priceUsdcStroops: jsonSerialization['priceUsdcStroops'] as int,
      wallet: jsonSerialization['wallet'] as String?,
      model: jsonSerialization['model'] as String?,
    );
  }

  static final t = AgentRecordTable();

  static const db = AgentRecordRepository._();

  @override
  int? id;

  /// The on-chain integer id in the identity registry.
  int registryId;

  /// The metadata id of the agent, for example agt-001.
  String agentId;

  /// The display name.
  String name;

  /// What the agent does.
  String description;

  /// The skill ids, in kebab-case, in the stored order.
  List<String> skills;

  /// The price of one hire in USDC stroops.
  int priceUsdcStroops;

  /// The Stellar address (G...) that receives payments, when registered.
  String? wallet;

  /// The model that runs the agent, when the metadata names one.
  String? model;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AgentRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AgentRecord copyWith({
    int? id,
    int? registryId,
    String? agentId,
    String? name,
    String? description,
    List<String>? skills,
    int? priceUsdcStroops,
    String? wallet,
    String? model,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AgentRecord',
      if (id != null) 'id': id,
      'registryId': registryId,
      'agentId': agentId,
      'name': name,
      'description': description,
      'skills': skills.toJson(),
      'priceUsdcStroops': priceUsdcStroops,
      if (wallet != null) 'wallet': wallet,
      if (model != null) 'model': model,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AgentRecordInclude include() {
    return AgentRecordInclude._();
  }

  static AgentRecordIncludeList includeList({
    _is.WhereExpressionBuilder<AgentRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AgentRecordTable>? orderBy,
    _is.OrderByListBuilder<AgentRecordTable>? orderByList,
    AgentRecordInclude? include,
  }) {
    return AgentRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentRecord.t),
      orderByList: orderByList?.call(AgentRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AgentRecordImpl extends AgentRecord {
  _AgentRecordImpl({
    int? id,
    required int registryId,
    required String agentId,
    required String name,
    required String description,
    required List<String> skills,
    required int priceUsdcStroops,
    String? wallet,
    String? model,
  }) : super._(
         id: id,
         registryId: registryId,
         agentId: agentId,
         name: name,
         description: description,
         skills: skills,
         priceUsdcStroops: priceUsdcStroops,
         wallet: wallet,
         model: model,
       );

  /// Returns a shallow copy of this [AgentRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AgentRecord copyWith({
    Object? id = _Undefined,
    int? registryId,
    String? agentId,
    String? name,
    String? description,
    List<String>? skills,
    int? priceUsdcStroops,
    Object? wallet = _Undefined,
    Object? model = _Undefined,
  }) {
    return AgentRecord(
      id: id is int? ? id : this.id,
      registryId: registryId ?? this.registryId,
      agentId: agentId ?? this.agentId,
      name: name ?? this.name,
      description: description ?? this.description,
      skills: skills ?? this.skills.map((e0) => e0).toList(),
      priceUsdcStroops: priceUsdcStroops ?? this.priceUsdcStroops,
      wallet: wallet is String? ? wallet : this.wallet,
      model: model is String? ? model : this.model,
    );
  }
}

class AgentRecordUpdateTable extends _is.UpdateTable<AgentRecordTable> {
  AgentRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> registryId(int value) => _is.ColumnValue(
    table.registryId,
    value,
  );

  _is.ColumnValue<String, String> agentId(String value) => _is.ColumnValue(
    table.agentId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<String, String> description(String value) => _is.ColumnValue(
    table.description,
    value,
  );

  _is.ColumnValue<List<String>, List<String>> skills(List<String> value) =>
      _is.ColumnValue(
        table.skills,
        value,
      );

  _is.ColumnValue<int, int> priceUsdcStroops(int value) => _is.ColumnValue(
    table.priceUsdcStroops,
    value,
  );

  _is.ColumnValue<String, String> wallet(String? value) => _is.ColumnValue(
    table.wallet,
    value,
  );

  _is.ColumnValue<String, String> model(String? value) => _is.ColumnValue(
    table.model,
    value,
  );
}

class AgentRecordTable extends _is.Table<int?> {
  AgentRecordTable({super.tableRelation}) : super(tableName: 'agent_record') {
    updateTable = AgentRecordUpdateTable(this);
    registryId = _is.ColumnInt(
      'registryId',
      this,
    );
    agentId = _is.ColumnString(
      'agentId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    description = _is.ColumnString(
      'description',
      this,
    );
    skills = _is.ColumnSerializable<List<String>>(
      'skills',
      this,
    );
    priceUsdcStroops = _is.ColumnInt(
      'priceUsdcStroops',
      this,
    );
    wallet = _is.ColumnString(
      'wallet',
      this,
    );
    model = _is.ColumnString(
      'model',
      this,
    );
  }

  late final AgentRecordUpdateTable updateTable;

  /// The on-chain integer id in the identity registry.
  late final _is.ColumnInt registryId;

  /// The metadata id of the agent, for example agt-001.
  late final _is.ColumnString agentId;

  /// The display name.
  late final _is.ColumnString name;

  /// What the agent does.
  late final _is.ColumnString description;

  /// The skill ids, in kebab-case, in the stored order.
  late final _is.ColumnSerializable<List<String>> skills;

  /// The price of one hire in USDC stroops.
  late final _is.ColumnInt priceUsdcStroops;

  /// The Stellar address (G...) that receives payments, when registered.
  late final _is.ColumnString wallet;

  /// The model that runs the agent, when the metadata names one.
  late final _is.ColumnString model;

  @override
  List<_is.Column> get columns => [
    id,
    registryId,
    agentId,
    name,
    description,
    skills,
    priceUsdcStroops,
    wallet,
    model,
  ];
}

class AgentRecordInclude extends _is.IncludeObject {
  AgentRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AgentRecord.t;
}

class AgentRecordIncludeList extends _is.IncludeList {
  AgentRecordIncludeList._({
    _is.WhereExpressionBuilder<AgentRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AgentRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AgentRecord.t;
}

class AgentRecordRepository {
  const AgentRecordRepository._();

  /// Returns a list of [AgentRecord]s matching the given query parameters.
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
  Future<List<AgentRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AgentRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AgentRecordTable>? orderBy,
    _is.OrderByListBuilder<AgentRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AgentRecord>(
      where: where?.call(AgentRecord.t),
      orderBy: orderBy?.call(AgentRecord.t),
      orderByList: orderByList?.call(AgentRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AgentRecord] matching the given query parameters.
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
  Future<AgentRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AgentRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<AgentRecordTable>? orderBy,
    _is.OrderByListBuilder<AgentRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AgentRecord>(
      where: where?.call(AgentRecord.t),
      orderBy: orderBy?.call(AgentRecord.t),
      orderByList: orderByList?.call(AgentRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AgentRecord] by its [id] or null if no such row exists.
  Future<AgentRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AgentRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AgentRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [AgentRecord]s will have their `id` fields set.
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
  Future<List<AgentRecord>> insert(
    _is.DatabaseSession session,
    List<AgentRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AgentRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AgentRecord] and returns the inserted row.
  ///
  /// The returned [AgentRecord] will have its `id` field set.
  Future<AgentRecord> insertRow(
    _is.DatabaseSession session,
    AgentRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AgentRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AgentRecord]s in the list and returns the resulting rows.
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
  /// The returned [AgentRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AgentRecord>> upsert(
    _is.DatabaseSession session,
    List<AgentRecord> rows, {
    required _is.ColumnSelections<AgentRecordTable> conflictColumns,
    _is.ColumnSelections<AgentRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<AgentRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AgentRecord>(
      rows,
      conflictColumns: conflictColumns(AgentRecord.t),
      updateColumns: updateColumns?.call(AgentRecord.t),
      updateWhere: updateWhere?.call(AgentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AgentRecord] and returns the resulting row.
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
  /// The returned [AgentRecord] will have its `id` field set.
  Future<AgentRecord?> upsertRow(
    _is.DatabaseSession session,
    AgentRecord row, {
    required _is.ColumnSelections<AgentRecordTable> conflictColumns,
    _is.ColumnSelections<AgentRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<AgentRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AgentRecord>(
      row,
      conflictColumns: conflictColumns(AgentRecord.t),
      updateColumns: updateColumns?.call(AgentRecord.t),
      updateWhere: updateWhere?.call(AgentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [AgentRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AgentRecord>> update(
    _is.DatabaseSession session,
    List<AgentRecord> rows, {
    _is.ColumnSelections<AgentRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AgentRecord>(
      rows,
      columns: columns?.call(AgentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AgentRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AgentRecord> updateRow(
    _is.DatabaseSession session,
    AgentRecord row, {
    _is.ColumnSelections<AgentRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AgentRecord>(
      row,
      columns: columns?.call(AgentRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AgentRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AgentRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AgentRecordUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AgentRecord>(
      id,
      columnValues: columnValues(AgentRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AgentRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AgentRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AgentRecordUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AgentRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AgentRecordTable>? orderBy,
    _is.OrderByListBuilder<AgentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AgentRecord>(
      columnValues: columnValues(AgentRecord.t.updateTable),
      where: where(AgentRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AgentRecord.t),
      orderByList: orderByList?.call(AgentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AgentRecord]s in the list and returns the deleted rows.
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
  Future<List<AgentRecord>> delete(
    _is.DatabaseSession session,
    List<AgentRecord> rows, {
    _is.OrderByBuilder<AgentRecordTable>? orderBy,
    _is.OrderByListBuilder<AgentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AgentRecord>(
      rows,
      orderBy: orderBy?.call(AgentRecord.t),
      orderByList: orderByList?.call(AgentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AgentRecord].
  Future<AgentRecord> deleteRow(
    _is.DatabaseSession session,
    AgentRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AgentRecord>(
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
  Future<List<AgentRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AgentRecordTable> where,
    _is.OrderByBuilder<AgentRecordTable>? orderBy,
    _is.OrderByListBuilder<AgentRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AgentRecord>(
      where: where(AgentRecord.t),
      orderBy: orderBy?.call(AgentRecord.t),
      orderByList: orderByList?.call(AgentRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AgentRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AgentRecord>(
      where: where?.call(AgentRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AgentRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AgentRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AgentRecord>(
      where: where(AgentRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
