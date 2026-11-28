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
import 'dart:async' as _ida;
import 'package:serverpod/serverpod.dart' as _is;

/// One child job on the itemized receipt of a parent hire (ADR-0011 D6):
/// who was subcontracted, for how much, what it paid and where it is. The
/// server joins the escrow events and the child hire into these lines; every
/// transaction hash links to StellarExpert.
abstract class HireReceiptLineRecord
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  HireReceiptLineRecord._({
    this.id,
    required this.parentHireId,
    this.childHireId,
    this.childJobId,
    required this.providerAgentId,
    required this.providerWallet,
    required this.budget,
    this.fee,
    this.payout,
    required this.state,
    this.deliverableHash,
    this.createTransaction,
    this.settleTransaction,
    required this.relatedParty,
    required this.justification,
    required this.createdAt,
  });

  factory HireReceiptLineRecord({
    int? id,
    required int parentHireId,
    int? childHireId,
    int? childJobId,
    required int providerAgentId,
    required String providerWallet,
    required int budget,
    int? fee,
    int? payout,
    required String state,
    String? deliverableHash,
    String? createTransaction,
    String? settleTransaction,
    required bool relatedParty,
    required String justification,
    required DateTime createdAt,
  }) = _HireReceiptLineRecordImpl;

  factory HireReceiptLineRecord.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return HireReceiptLineRecord(
      id: jsonSerialization['id'] as int?,
      parentHireId: jsonSerialization['parentHireId'] as int,
      childHireId: jsonSerialization['childHireId'] as int?,
      childJobId: jsonSerialization['childJobId'] as int?,
      providerAgentId: jsonSerialization['providerAgentId'] as int,
      providerWallet: jsonSerialization['providerWallet'] as String,
      budget: jsonSerialization['budget'] as int,
      fee: jsonSerialization['fee'] as int?,
      payout: jsonSerialization['payout'] as int?,
      state: jsonSerialization['state'] as String,
      deliverableHash: jsonSerialization['deliverableHash'] as String?,
      createTransaction: jsonSerialization['createTransaction'] as String?,
      settleTransaction: jsonSerialization['settleTransaction'] as String?,
      relatedParty: _is.BoolJsonExtension.fromJson(
        jsonSerialization['relatedParty'],
      ),
      justification: jsonSerialization['justification'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  static final t = HireReceiptLineRecordTable();

  static const db = HireReceiptLineRecordRepository._();

  @override
  int? id;

  /// The hire whose reserve funded the child job.
  int parentHireId;

  /// The child hire, once it is stored (ADR-0011 D7).
  int? childHireId;

  /// Escrow id of the child job, set once create_child_job is confirmed.
  int? childJobId;

  /// Registry id of the subcontracted agent.
  int providerAgentId;

  /// StrKey of the subcontracted agent's payment wallet.
  String providerWallet;

  /// USDC stroops drawn from the parent reserve as the child budget.
  int budget;

  /// USDC stroops of platform fee, set when the child completes.
  int? fee;

  /// USDC stroops paid to the provider, set when the child completes.
  int? payout;

  /// HireStatus name of the child job: open, funded, submitted, completed,
  /// rejected, expired.
  String state;

  /// The child's deliverable hash, lowercase hex, once it is submitted.
  String? deliverableHash;

  /// The create_child_job transaction hash, lowercase hex.
  String? createTransaction;

  /// The transaction that settled the child (complete, release, reject or
  /// claim_refund), lowercase hex.
  String? settleTransaction;

  /// True when the provider has the same owner as the parent's agent (D10).
  bool relatedParty;

  /// The parent agent's justification of the pick, against the ranking.
  String justification;

  DateTime createdAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [HireReceiptLineRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  HireReceiptLineRecord copyWith({
    int? id,
    int? parentHireId,
    int? childHireId,
    int? childJobId,
    int? providerAgentId,
    String? providerWallet,
    int? budget,
    int? fee,
    int? payout,
    String? state,
    String? deliverableHash,
    String? createTransaction,
    String? settleTransaction,
    bool? relatedParty,
    String? justification,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireReceiptLineRecord',
      if (id != null) 'id': id,
      'parentHireId': parentHireId,
      if (childHireId != null) 'childHireId': childHireId,
      if (childJobId != null) 'childJobId': childJobId,
      'providerAgentId': providerAgentId,
      'providerWallet': providerWallet,
      'budget': budget,
      if (fee != null) 'fee': fee,
      if (payout != null) 'payout': payout,
      'state': state,
      if (deliverableHash != null) 'deliverableHash': deliverableHash,
      if (createTransaction != null) 'createTransaction': createTransaction,
      if (settleTransaction != null) 'settleTransaction': settleTransaction,
      'relatedParty': relatedParty,
      'justification': justification,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static HireReceiptLineRecordInclude include() {
    return HireReceiptLineRecordInclude._();
  }

  static HireReceiptLineRecordIncludeList includeList({
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    HireReceiptLineRecordInclude? include,
  }) {
    return HireReceiptLineRecordIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireReceiptLineRecordImpl extends HireReceiptLineRecord {
  _HireReceiptLineRecordImpl({
    int? id,
    required int parentHireId,
    int? childHireId,
    int? childJobId,
    required int providerAgentId,
    required String providerWallet,
    required int budget,
    int? fee,
    int? payout,
    required String state,
    String? deliverableHash,
    String? createTransaction,
    String? settleTransaction,
    required bool relatedParty,
    required String justification,
    required DateTime createdAt,
  }) : super._(
         id: id,
         parentHireId: parentHireId,
         childHireId: childHireId,
         childJobId: childJobId,
         providerAgentId: providerAgentId,
         providerWallet: providerWallet,
         budget: budget,
         fee: fee,
         payout: payout,
         state: state,
         deliverableHash: deliverableHash,
         createTransaction: createTransaction,
         settleTransaction: settleTransaction,
         relatedParty: relatedParty,
         justification: justification,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [HireReceiptLineRecord]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  HireReceiptLineRecord copyWith({
    Object? id = _Undefined,
    int? parentHireId,
    Object? childHireId = _Undefined,
    Object? childJobId = _Undefined,
    int? providerAgentId,
    String? providerWallet,
    int? budget,
    Object? fee = _Undefined,
    Object? payout = _Undefined,
    String? state,
    Object? deliverableHash = _Undefined,
    Object? createTransaction = _Undefined,
    Object? settleTransaction = _Undefined,
    bool? relatedParty,
    String? justification,
    DateTime? createdAt,
  }) {
    return HireReceiptLineRecord(
      id: id is int? ? id : this.id,
      parentHireId: parentHireId ?? this.parentHireId,
      childHireId: childHireId is int? ? childHireId : this.childHireId,
      childJobId: childJobId is int? ? childJobId : this.childJobId,
      providerAgentId: providerAgentId ?? this.providerAgentId,
      providerWallet: providerWallet ?? this.providerWallet,
      budget: budget ?? this.budget,
      fee: fee is int? ? fee : this.fee,
      payout: payout is int? ? payout : this.payout,
      state: state ?? this.state,
      deliverableHash: deliverableHash is String?
          ? deliverableHash
          : this.deliverableHash,
      createTransaction: createTransaction is String?
          ? createTransaction
          : this.createTransaction,
      settleTransaction: settleTransaction is String?
          ? settleTransaction
          : this.settleTransaction,
      relatedParty: relatedParty ?? this.relatedParty,
      justification: justification ?? this.justification,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class HireReceiptLineRecordUpdateTable
    extends _is.UpdateTable<HireReceiptLineRecordTable> {
  HireReceiptLineRecordUpdateTable(super.table);

  _is.ColumnValue<int, int> parentHireId(int value) => _is.ColumnValue(
    table.parentHireId,
    value,
  );

  _is.ColumnValue<int, int> childHireId(int? value) => _is.ColumnValue(
    table.childHireId,
    value,
  );

  _is.ColumnValue<int, int> childJobId(int? value) => _is.ColumnValue(
    table.childJobId,
    value,
  );

  _is.ColumnValue<int, int> providerAgentId(int value) => _is.ColumnValue(
    table.providerAgentId,
    value,
  );

  _is.ColumnValue<String, String> providerWallet(String value) =>
      _is.ColumnValue(
        table.providerWallet,
        value,
      );

  _is.ColumnValue<int, int> budget(int value) => _is.ColumnValue(
    table.budget,
    value,
  );

  _is.ColumnValue<int, int> fee(int? value) => _is.ColumnValue(
    table.fee,
    value,
  );

  _is.ColumnValue<int, int> payout(int? value) => _is.ColumnValue(
    table.payout,
    value,
  );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<String, String> deliverableHash(String? value) =>
      _is.ColumnValue(
        table.deliverableHash,
        value,
      );

  _is.ColumnValue<String, String> createTransaction(String? value) =>
      _is.ColumnValue(
        table.createTransaction,
        value,
      );

  _is.ColumnValue<String, String> settleTransaction(String? value) =>
      _is.ColumnValue(
        table.settleTransaction,
        value,
      );

  _is.ColumnValue<bool, bool> relatedParty(bool value) => _is.ColumnValue(
    table.relatedParty,
    value,
  );

  _is.ColumnValue<String, String> justification(String value) =>
      _is.ColumnValue(
        table.justification,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );
}

class HireReceiptLineRecordTable extends _is.Table<int?> {
  HireReceiptLineRecordTable({super.tableRelation})
    : super(tableName: 'hire_receipt_line') {
    updateTable = HireReceiptLineRecordUpdateTable(this);
    parentHireId = _is.ColumnInt(
      'parentHireId',
      this,
    );
    childHireId = _is.ColumnInt(
      'childHireId',
      this,
    );
    childJobId = _is.ColumnInt(
      'childJobId',
      this,
    );
    providerAgentId = _is.ColumnInt(
      'providerAgentId',
      this,
    );
    providerWallet = _is.ColumnString(
      'providerWallet',
      this,
    );
    budget = _is.ColumnInt(
      'budget',
      this,
    );
    fee = _is.ColumnInt(
      'fee',
      this,
    );
    payout = _is.ColumnInt(
      'payout',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    deliverableHash = _is.ColumnString(
      'deliverableHash',
      this,
    );
    createTransaction = _is.ColumnString(
      'createTransaction',
      this,
    );
    settleTransaction = _is.ColumnString(
      'settleTransaction',
      this,
    );
    relatedParty = _is.ColumnBool(
      'relatedParty',
      this,
    );
    justification = _is.ColumnString(
      'justification',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final HireReceiptLineRecordUpdateTable updateTable;

  /// The hire whose reserve funded the child job.
  late final _is.ColumnInt parentHireId;

  /// The child hire, once it is stored (ADR-0011 D7).
  late final _is.ColumnInt childHireId;

  /// Escrow id of the child job, set once create_child_job is confirmed.
  late final _is.ColumnInt childJobId;

  /// Registry id of the subcontracted agent.
  late final _is.ColumnInt providerAgentId;

  /// StrKey of the subcontracted agent's payment wallet.
  late final _is.ColumnString providerWallet;

  /// USDC stroops drawn from the parent reserve as the child budget.
  late final _is.ColumnInt budget;

  /// USDC stroops of platform fee, set when the child completes.
  late final _is.ColumnInt fee;

  /// USDC stroops paid to the provider, set when the child completes.
  late final _is.ColumnInt payout;

  /// HireStatus name of the child job: open, funded, submitted, completed,
  /// rejected, expired.
  late final _is.ColumnString state;

  /// The child's deliverable hash, lowercase hex, once it is submitted.
  late final _is.ColumnString deliverableHash;

  /// The create_child_job transaction hash, lowercase hex.
  late final _is.ColumnString createTransaction;

  /// The transaction that settled the child (complete, release, reject or
  /// claim_refund), lowercase hex.
  late final _is.ColumnString settleTransaction;

  /// True when the provider has the same owner as the parent's agent (D10).
  late final _is.ColumnBool relatedParty;

  /// The parent agent's justification of the pick, against the ranking.
  late final _is.ColumnString justification;

  late final _is.ColumnDateTime createdAt;

  @override
  List<_is.Column> get columns => [
    id,
    parentHireId,
    childHireId,
    childJobId,
    providerAgentId,
    providerWallet,
    budget,
    fee,
    payout,
    state,
    deliverableHash,
    createTransaction,
    settleTransaction,
    relatedParty,
    justification,
    createdAt,
  ];
}

class HireReceiptLineRecordInclude extends _is.IncludeObject {
  HireReceiptLineRecordInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => HireReceiptLineRecord.t;
}

class HireReceiptLineRecordIncludeList extends _is.IncludeList {
  HireReceiptLineRecordIncludeList._({
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(HireReceiptLineRecord.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => HireReceiptLineRecord.t;
}

class HireReceiptLineRecordRepository {
  const HireReceiptLineRecordRepository._();

  /// Returns a list of [HireReceiptLineRecord]s matching the given query parameters.
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
  Future<List<HireReceiptLineRecord>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<HireReceiptLineRecord>(
      where: where?.call(HireReceiptLineRecord.t),
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [HireReceiptLineRecord]s matching the given query parameters every time the
  /// source tables are modified.
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
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `HireReceiptLineRecord.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<HireReceiptLineRecord>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<HireReceiptLineRecord>(
      where: where?.call(HireReceiptLineRecord.t),
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [HireReceiptLineRecord] matching the given query parameters.
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
  Future<HireReceiptLineRecord?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? where,
    int? offset,
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<HireReceiptLineRecord>(
      where: where?.call(HireReceiptLineRecord.t),
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [HireReceiptLineRecord] by its [id] or null if no such row exists.
  Future<HireReceiptLineRecord?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<HireReceiptLineRecord>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [HireReceiptLineRecord]s in the list and returns the inserted rows.
  ///
  /// The returned [HireReceiptLineRecord]s will have their `id` fields set.
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
  Future<List<HireReceiptLineRecord>> insert(
    _is.DatabaseSession session,
    List<HireReceiptLineRecord> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<HireReceiptLineRecord>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [HireReceiptLineRecord] and returns the inserted row.
  ///
  /// The returned [HireReceiptLineRecord] will have its `id` field set.
  Future<HireReceiptLineRecord> insertRow(
    _is.DatabaseSession session,
    HireReceiptLineRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<HireReceiptLineRecord>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [HireReceiptLineRecord]s in the list and returns the resulting rows.
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
  /// The returned [HireReceiptLineRecord]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireReceiptLineRecord>> upsert(
    _is.DatabaseSession session,
    List<HireReceiptLineRecord> rows, {
    required _is.ColumnSelections<HireReceiptLineRecordTable> conflictColumns,
    _is.ColumnSelections<HireReceiptLineRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<HireReceiptLineRecord>(
      rows,
      conflictColumns: conflictColumns(HireReceiptLineRecord.t),
      updateColumns: updateColumns?.call(HireReceiptLineRecord.t),
      updateWhere: updateWhere?.call(HireReceiptLineRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [HireReceiptLineRecord] and returns the resulting row.
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
  /// The returned [HireReceiptLineRecord] will have its `id` field set.
  Future<HireReceiptLineRecord?> upsertRow(
    _is.DatabaseSession session,
    HireReceiptLineRecord row, {
    required _is.ColumnSelections<HireReceiptLineRecordTable> conflictColumns,
    _is.ColumnSelections<HireReceiptLineRecordTable>? updateColumns,
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<HireReceiptLineRecord>(
      row,
      conflictColumns: conflictColumns(HireReceiptLineRecord.t),
      updateColumns: updateColumns?.call(HireReceiptLineRecord.t),
      updateWhere: updateWhere?.call(HireReceiptLineRecord.t),
      transaction: transaction,
    );
  }

  /// Updates all [HireReceiptLineRecord]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireReceiptLineRecord>> update(
    _is.DatabaseSession session,
    List<HireReceiptLineRecord> rows, {
    _is.ColumnSelections<HireReceiptLineRecordTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<HireReceiptLineRecord>(
      rows,
      columns: columns?.call(HireReceiptLineRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [HireReceiptLineRecord]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<HireReceiptLineRecord> updateRow(
    _is.DatabaseSession session,
    HireReceiptLineRecord row, {
    _is.ColumnSelections<HireReceiptLineRecordTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<HireReceiptLineRecord>(
      row,
      columns: columns?.call(HireReceiptLineRecord.t),
      transaction: transaction,
    );
  }

  /// Updates a single [HireReceiptLineRecord] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<HireReceiptLineRecord?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<HireReceiptLineRecordUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<HireReceiptLineRecord>(
      id,
      columnValues: columnValues(HireReceiptLineRecord.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [HireReceiptLineRecord]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<HireReceiptLineRecord>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<HireReceiptLineRecordUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<HireReceiptLineRecordTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<HireReceiptLineRecord>(
      columnValues: columnValues(HireReceiptLineRecord.t.updateTable),
      where: where(HireReceiptLineRecord.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [HireReceiptLineRecord]s in the list and returns the deleted rows.
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
  Future<List<HireReceiptLineRecord>> delete(
    _is.DatabaseSession session,
    List<HireReceiptLineRecord> rows, {
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<HireReceiptLineRecord>(
      rows,
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [HireReceiptLineRecord].
  Future<HireReceiptLineRecord> deleteRow(
    _is.DatabaseSession session,
    HireReceiptLineRecord row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<HireReceiptLineRecord>(
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
  Future<List<HireReceiptLineRecord>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HireReceiptLineRecordTable> where,
    _is.OrderByBuilder<HireReceiptLineRecordTable>? orderBy,
    _is.OrderByListBuilder<HireReceiptLineRecordTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<HireReceiptLineRecord>(
      where: where(HireReceiptLineRecord.t),
      orderBy: orderBy?.call(HireReceiptLineRecord.t),
      orderByList: orderByList?.call(HireReceiptLineRecord.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<HireReceiptLineRecordTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<HireReceiptLineRecord>(
      where: where?.call(HireReceiptLineRecord.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [HireReceiptLineRecord] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<HireReceiptLineRecordTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<HireReceiptLineRecord>(
      where: where(HireReceiptLineRecord.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
