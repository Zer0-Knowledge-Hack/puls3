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

/// Durable server-side record of one relay or server-signed submission.
/// Polled through the resource that owns it; the client sees only the
/// fields without `scope=serverOnly`. Serverpod requires serverOnly fields to
/// be nullable; ChainSubmissionStore always sets them.
abstract class ChainSubmission
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  ChainSubmission._({
    this.id,
    this.preparationId,
    required this.purpose,
    required this.transaction,
    required this.state,
    this.errorCode,
    this.explorerUrl,
    required this.updatedAt,
    this.hireId,
    this.signedEnvelopeXdr,
    this.validUntil,
    this.lastSentAt,
    int? sendAttempts,
    this.createdAt,
  }) : sendAttempts = sendAttempts ?? 0;

  factory ChainSubmission({
    int? id,
    String? preparationId,
    required String purpose,
    required String transaction,
    required String state,
    String? errorCode,
    String? explorerUrl,
    required DateTime updatedAt,
    int? hireId,
    String? signedEnvelopeXdr,
    DateTime? validUntil,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? createdAt,
  }) = _ChainSubmissionImpl;

  factory ChainSubmission.fromJson(Map<String, dynamic> jsonSerialization) {
    return ChainSubmission(
      id: jsonSerialization['id'] as int?,
      preparationId: jsonSerialization['preparationId'] as String?,
      purpose: jsonSerialization['purpose'] as String,
      transaction: jsonSerialization['transaction'] as String,
      state: jsonSerialization['state'] as String,
      errorCode: jsonSerialization['errorCode'] as String?,
      explorerUrl: jsonSerialization['explorerUrl'] as String?,
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      hireId: jsonSerialization['hireId'] as int?,
      signedEnvelopeXdr: jsonSerialization['signedEnvelopeXdr'] as String?,
      validUntil: jsonSerialization['validUntil'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['validUntil']),
      lastSentAt: jsonSerialization['lastSentAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['lastSentAt']),
      sendAttempts: jsonSerialization['sendAttempts'] as int?,
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = ChainSubmissionTable();

  static const db = ChainSubmissionRepository._();

  @override
  int? id;

  /// The PreparedTransaction this submission came from. Null for
  /// server-signed purposes (submit, release, claimRefund).
  String? preparationId;

  /// One of registerFull, setAgentWallet, createJob, fund, complete, reject,
  /// giveFeedback (wallet-signed), or submit, release, claimRefund
  /// (server-signed).
  String purpose;

  /// Domain TransactionHash of the one envelope this record ever sends,
  /// persisted before it is submitted.
  String transaction;

  /// One of submitted, confirmed, failed.
  String state;

  /// Puls3ApiException code when state is failed, for example JobMismatch.
  /// Chain outcomes are reported here, never thrown by submit methods.
  String? errorCode;

  String? explorerUrl;

  DateTime updatedAt;

  /// The hire this submission belongs to, when it has one.
  int? hireId;

  /// The signed envelope in base64 XDR; resent unchanged when needed.
  String? signedEnvelopeXdr;

  /// End of the envelope time bounds; after it the submission is expired.
  DateTime? validUntil;

  DateTime? lastSentAt;

  int? sendAttempts;

  DateTime? createdAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [ChainSubmission]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ChainSubmission copyWith({
    int? id,
    String? preparationId,
    String? purpose,
    String? transaction,
    String? state,
    String? errorCode,
    String? explorerUrl,
    DateTime? updatedAt,
    int? hireId,
    String? signedEnvelopeXdr,
    DateTime? validUntil,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ChainSubmission',
      if (id != null) 'id': id,
      if (preparationId != null) 'preparationId': preparationId,
      'purpose': purpose,
      'transaction': transaction,
      'state': state,
      if (errorCode != null) 'errorCode': errorCode,
      if (explorerUrl != null) 'explorerUrl': explorerUrl,
      'updatedAt': updatedAt.toJson(),
      if (hireId != null) 'hireId': hireId,
      if (signedEnvelopeXdr != null) 'signedEnvelopeXdr': signedEnvelopeXdr,
      if (validUntil != null) 'validUntil': validUntil?.toJson(),
      if (lastSentAt != null) 'lastSentAt': lastSentAt?.toJson(),
      if (sendAttempts != null) 'sendAttempts': sendAttempts,
      if (createdAt != null) 'createdAt': createdAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ChainSubmission',
      if (id != null) 'id': id,
      if (preparationId != null) 'preparationId': preparationId,
      'purpose': purpose,
      'transaction': transaction,
      'state': state,
      if (errorCode != null) 'errorCode': errorCode,
      if (explorerUrl != null) 'explorerUrl': explorerUrl,
      'updatedAt': updatedAt.toJson(),
    };
  }

  static ChainSubmissionInclude include() {
    return ChainSubmissionInclude._();
  }

  static ChainSubmissionIncludeList includeList({
    _i1.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChainSubmissionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    ChainSubmissionInclude? include,
  }) {
    return ChainSubmissionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChainSubmission.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(ChainSubmission.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ChainSubmissionImpl extends ChainSubmission {
  _ChainSubmissionImpl({
    int? id,
    String? preparationId,
    required String purpose,
    required String transaction,
    required String state,
    String? errorCode,
    String? explorerUrl,
    required DateTime updatedAt,
    int? hireId,
    String? signedEnvelopeXdr,
    DateTime? validUntil,
    DateTime? lastSentAt,
    int? sendAttempts,
    DateTime? createdAt,
  }) : super._(
         id: id,
         preparationId: preparationId,
         purpose: purpose,
         transaction: transaction,
         state: state,
         errorCode: errorCode,
         explorerUrl: explorerUrl,
         updatedAt: updatedAt,
         hireId: hireId,
         signedEnvelopeXdr: signedEnvelopeXdr,
         validUntil: validUntil,
         lastSentAt: lastSentAt,
         sendAttempts: sendAttempts,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [ChainSubmission]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ChainSubmission copyWith({
    Object? id = _Undefined,
    Object? preparationId = _Undefined,
    String? purpose,
    String? transaction,
    String? state,
    Object? errorCode = _Undefined,
    Object? explorerUrl = _Undefined,
    DateTime? updatedAt,
    Object? hireId = _Undefined,
    Object? signedEnvelopeXdr = _Undefined,
    Object? validUntil = _Undefined,
    Object? lastSentAt = _Undefined,
    Object? sendAttempts = _Undefined,
    Object? createdAt = _Undefined,
  }) {
    return ChainSubmission(
      id: id is int? ? id : this.id,
      preparationId: preparationId is String?
          ? preparationId
          : this.preparationId,
      purpose: purpose ?? this.purpose,
      transaction: transaction ?? this.transaction,
      state: state ?? this.state,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      explorerUrl: explorerUrl is String? ? explorerUrl : this.explorerUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      hireId: hireId is int? ? hireId : this.hireId,
      signedEnvelopeXdr: signedEnvelopeXdr is String?
          ? signedEnvelopeXdr
          : this.signedEnvelopeXdr,
      validUntil: validUntil is DateTime? ? validUntil : this.validUntil,
      lastSentAt: lastSentAt is DateTime? ? lastSentAt : this.lastSentAt,
      sendAttempts: sendAttempts is int? ? sendAttempts : this.sendAttempts,
      createdAt: createdAt is DateTime? ? createdAt : this.createdAt,
    );
  }
}

class ChainSubmissionUpdateTable extends _i1.UpdateTable<ChainSubmissionTable> {
  ChainSubmissionUpdateTable(super.table);

  _i1.ColumnValue<String, String> preparationId(String? value) =>
      _i1.ColumnValue(
        table.preparationId,
        value,
      );

  _i1.ColumnValue<String, String> purpose(String value) => _i1.ColumnValue(
    table.purpose,
    value,
  );

  _i1.ColumnValue<String, String> transaction(String value) => _i1.ColumnValue(
    table.transaction,
    value,
  );

  _i1.ColumnValue<String, String> state(String value) => _i1.ColumnValue(
    table.state,
    value,
  );

  _i1.ColumnValue<String, String> errorCode(String? value) => _i1.ColumnValue(
    table.errorCode,
    value,
  );

  _i1.ColumnValue<String, String> explorerUrl(String? value) => _i1.ColumnValue(
    table.explorerUrl,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _i1.ColumnValue(
        table.updatedAt,
        value,
      );

  _i1.ColumnValue<int, int> hireId(int? value) => _i1.ColumnValue(
    table.hireId,
    value,
  );

  _i1.ColumnValue<String, String> signedEnvelopeXdr(String? value) =>
      _i1.ColumnValue(
        table.signedEnvelopeXdr,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> validUntil(DateTime? value) =>
      _i1.ColumnValue(
        table.validUntil,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastSentAt(DateTime? value) =>
      _i1.ColumnValue(
        table.lastSentAt,
        value,
      );

  _i1.ColumnValue<int, int> sendAttempts(int? value) => _i1.ColumnValue(
    table.sendAttempts,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime? value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );
}

class ChainSubmissionTable extends _i1.Table<int?> {
  ChainSubmissionTable({super.tableRelation})
    : super(tableName: 'chain_submission') {
    updateTable = ChainSubmissionUpdateTable(this);
    preparationId = _i1.ColumnString(
      'preparationId',
      this,
    );
    purpose = _i1.ColumnString(
      'purpose',
      this,
    );
    transaction = _i1.ColumnString(
      'transaction',
      this,
    );
    state = _i1.ColumnString(
      'state',
      this,
    );
    errorCode = _i1.ColumnString(
      'errorCode',
      this,
    );
    explorerUrl = _i1.ColumnString(
      'explorerUrl',
      this,
    );
    updatedAt = _i1.ColumnDateTime(
      'updatedAt',
      this,
    );
    hireId = _i1.ColumnInt(
      'hireId',
      this,
    );
    signedEnvelopeXdr = _i1.ColumnString(
      'signedEnvelopeXdr',
      this,
    );
    validUntil = _i1.ColumnDateTime(
      'validUntil',
      this,
    );
    lastSentAt = _i1.ColumnDateTime(
      'lastSentAt',
      this,
    );
    sendAttempts = _i1.ColumnInt(
      'sendAttempts',
      this,
      hasDefault: true,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
  }

  late final ChainSubmissionUpdateTable updateTable;

  /// The PreparedTransaction this submission came from. Null for
  /// server-signed purposes (submit, release, claimRefund).
  late final _i1.ColumnString preparationId;

  /// One of registerFull, setAgentWallet, createJob, fund, complete, reject,
  /// giveFeedback (wallet-signed), or submit, release, claimRefund
  /// (server-signed).
  late final _i1.ColumnString purpose;

  /// Domain TransactionHash of the one envelope this record ever sends,
  /// persisted before it is submitted.
  late final _i1.ColumnString transaction;

  /// One of submitted, confirmed, failed.
  late final _i1.ColumnString state;

  /// Puls3ApiException code when state is failed, for example JobMismatch.
  /// Chain outcomes are reported here, never thrown by submit methods.
  late final _i1.ColumnString errorCode;

  late final _i1.ColumnString explorerUrl;

  late final _i1.ColumnDateTime updatedAt;

  /// The hire this submission belongs to, when it has one.
  late final _i1.ColumnInt hireId;

  /// The signed envelope in base64 XDR; resent unchanged when needed.
  late final _i1.ColumnString signedEnvelopeXdr;

  /// End of the envelope time bounds; after it the submission is expired.
  late final _i1.ColumnDateTime validUntil;

  late final _i1.ColumnDateTime lastSentAt;

  late final _i1.ColumnInt sendAttempts;

  late final _i1.ColumnDateTime createdAt;

  @override
  List<_i1.Column> get columns => [
    id,
    preparationId,
    purpose,
    transaction,
    state,
    errorCode,
    explorerUrl,
    updatedAt,
    hireId,
    signedEnvelopeXdr,
    validUntil,
    lastSentAt,
    sendAttempts,
    createdAt,
  ];
}

class ChainSubmissionInclude extends _i1.IncludeObject {
  ChainSubmissionInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => ChainSubmission.t;
}

class ChainSubmissionIncludeList extends _i1.IncludeList {
  ChainSubmissionIncludeList._({
    _i1.WhereExpressionBuilder<ChainSubmissionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ChainSubmission.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => ChainSubmission.t;
}

class ChainSubmissionRepository {
  const ChainSubmissionRepository._();

  /// Returns a list of [ChainSubmission]s matching the given query parameters.
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
  Future<List<ChainSubmission>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChainSubmissionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ChainSubmission>(
      where: where?.call(ChainSubmission.t),
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [ChainSubmission] matching the given query parameters.
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
  Future<ChainSubmission?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? offset,
    _i1.OrderByBuilder<ChainSubmissionTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ChainSubmission>(
      where: where?.call(ChainSubmission.t),
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ChainSubmission] by its [id] or null if no such row exists.
  Future<ChainSubmission?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ChainSubmission>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ChainSubmission]s in the list and returns the inserted rows.
  ///
  /// The returned [ChainSubmission]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<ChainSubmission>> insert(
    _i1.DatabaseSession session,
    List<ChainSubmission> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<ChainSubmission>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [ChainSubmission] and returns the inserted row.
  ///
  /// The returned [ChainSubmission] will have its `id` field set.
  Future<ChainSubmission> insertRow(
    _i1.DatabaseSession session,
    ChainSubmission row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<ChainSubmission>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [ChainSubmission]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<ChainSubmission>> update(
    _i1.DatabaseSession session,
    List<ChainSubmission> rows, {
    _i1.ColumnSelections<ChainSubmissionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<ChainSubmission>(
      rows,
      columns: columns?.call(ChainSubmission.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChainSubmission]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ChainSubmission> updateRow(
    _i1.DatabaseSession session,
    ChainSubmission row, {
    _i1.ColumnSelections<ChainSubmissionTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<ChainSubmission>(
      row,
      columns: columns?.call(ChainSubmission.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ChainSubmission] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ChainSubmission?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<ChainSubmissionUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<ChainSubmission>(
      id,
      columnValues: columnValues(ChainSubmission.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ChainSubmission]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<ChainSubmission>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<ChainSubmissionUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<ChainSubmissionTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ChainSubmissionTable>? orderBy,
    _i1.OrderByListBuilder<ChainSubmissionTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<ChainSubmission>(
      columnValues: columnValues(ChainSubmission.t.updateTable),
      where: where(ChainSubmission.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ChainSubmission.t),
      orderByList: orderByList?.call(ChainSubmission.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [ChainSubmission]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<ChainSubmission>> delete(
    _i1.DatabaseSession session,
    List<ChainSubmission> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<ChainSubmission>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [ChainSubmission].
  Future<ChainSubmission> deleteRow(
    _i1.DatabaseSession session,
    ChainSubmission row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ChainSubmission>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<ChainSubmission>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ChainSubmissionTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<ChainSubmission>(
      where: where(ChainSubmission.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<ChainSubmissionTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<ChainSubmission>(
      where: where?.call(ChainSubmission.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ChainSubmission] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<ChainSubmissionTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ChainSubmission>(
      where: where(ChainSubmission.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
