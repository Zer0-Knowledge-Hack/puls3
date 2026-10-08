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

/// One unsigned escrow envelope the server prepared for a session wallet.
/// Kept so that submit can verify the signed envelope against the exact
/// prepared bytes, and so a newer preparation can supersede an older one.
abstract class EscrowPreparation
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  EscrowPreparation._({
    this.id,
    required this.preparationId,
    required this.hireId,
    required this.purpose,
    required this.signer,
    required this.unsignedEnvelopeXdr,
    required this.transactionHash,
    required this.sequence,
    required this.validUntil,
    this.jobExpiredAt,
    this.rejectReason,
    required this.createdAt,
    this.supersededAt,
    this.submittedAt,
  });

  factory EscrowPreparation({
    int? id,
    required String preparationId,
    required int hireId,
    required String purpose,
    required String signer,
    required String unsignedEnvelopeXdr,
    required String transactionHash,
    required int sequence,
    required DateTime validUntil,
    int? jobExpiredAt,
    String? rejectReason,
    required DateTime createdAt,
    DateTime? supersededAt,
    DateTime? submittedAt,
  }) = _EscrowPreparationImpl;

  factory EscrowPreparation.fromJson(Map<String, dynamic> jsonSerialization) {
    return EscrowPreparation(
      id: jsonSerialization['id'] as int?,
      preparationId: jsonSerialization['preparationId'] as String,
      hireId: jsonSerialization['hireId'] as int,
      purpose: jsonSerialization['purpose'] as String,
      signer: jsonSerialization['signer'] as String,
      unsignedEnvelopeXdr: jsonSerialization['unsignedEnvelopeXdr'] as String,
      transactionHash: jsonSerialization['transactionHash'] as String,
      sequence: jsonSerialization['sequence'] as int,
      validUntil: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['validUntil'],
      ),
      jobExpiredAt: jsonSerialization['jobExpiredAt'] as int?,
      rejectReason: jsonSerialization['rejectReason'] as String?,
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      supersededAt: jsonSerialization['supersededAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['supersededAt'],
            ),
      submittedAt: jsonSerialization['submittedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['submittedAt'],
            ),
    );
  }

  static final t = EscrowPreparationTable();

  static const db = EscrowPreparationRepository._();

  @override
  int? id;

  /// Opaque id the client echoes back on submit.
  String preparationId;

  int hireId;

  /// createJob, fund, complete or reject.
  String purpose;

  /// StrKey of the session wallet that must sign.
  String signer;

  /// Base64 unsigned TransactionEnvelope XDR, exactly as returned.
  String unsignedEnvelopeXdr;

  /// Lowercase hex network hash of the prepared transaction.
  String transactionHash;

  /// Source account sequence number the envelope uses.
  int sequence;

  /// End of the envelope time bounds; after it the preparation is expired.
  DateTime validUntil;

  /// expired_at the create_job was prepared with; bound to the hire when the
  /// job is confirmed.
  int? jobExpiredAt;

  /// Reject reason baked into a reject envelope.
  String? rejectReason;

  DateTime createdAt;

  /// Set when a newer preparation replaced this one.
  DateTime? supersededAt;

  /// Set when a submit claimed this preparation.
  DateTime? submittedAt;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [EscrowPreparation]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  EscrowPreparation copyWith({
    int? id,
    String? preparationId,
    int? hireId,
    String? purpose,
    String? signer,
    String? unsignedEnvelopeXdr,
    String? transactionHash,
    int? sequence,
    DateTime? validUntil,
    int? jobExpiredAt,
    String? rejectReason,
    DateTime? createdAt,
    DateTime? supersededAt,
    DateTime? submittedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EscrowPreparation',
      if (id != null) 'id': id,
      'preparationId': preparationId,
      'hireId': hireId,
      'purpose': purpose,
      'signer': signer,
      'unsignedEnvelopeXdr': unsignedEnvelopeXdr,
      'transactionHash': transactionHash,
      'sequence': sequence,
      'validUntil': validUntil.toJson(),
      if (jobExpiredAt != null) 'jobExpiredAt': jobExpiredAt,
      if (rejectReason != null) 'rejectReason': rejectReason,
      'createdAt': createdAt.toJson(),
      if (supersededAt != null) 'supersededAt': supersededAt?.toJson(),
      if (submittedAt != null) 'submittedAt': submittedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static EscrowPreparationInclude include() {
    return EscrowPreparationInclude._();
  }

  static EscrowPreparationIncludeList includeList({
    _i1.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EscrowPreparationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    EscrowPreparationInclude? include,
  }) {
    return EscrowPreparationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(EscrowPreparation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EscrowPreparationImpl extends EscrowPreparation {
  _EscrowPreparationImpl({
    int? id,
    required String preparationId,
    required int hireId,
    required String purpose,
    required String signer,
    required String unsignedEnvelopeXdr,
    required String transactionHash,
    required int sequence,
    required DateTime validUntil,
    int? jobExpiredAt,
    String? rejectReason,
    required DateTime createdAt,
    DateTime? supersededAt,
    DateTime? submittedAt,
  }) : super._(
         id: id,
         preparationId: preparationId,
         hireId: hireId,
         purpose: purpose,
         signer: signer,
         unsignedEnvelopeXdr: unsignedEnvelopeXdr,
         transactionHash: transactionHash,
         sequence: sequence,
         validUntil: validUntil,
         jobExpiredAt: jobExpiredAt,
         rejectReason: rejectReason,
         createdAt: createdAt,
         supersededAt: supersededAt,
         submittedAt: submittedAt,
       );

  /// Returns a shallow copy of this [EscrowPreparation]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  EscrowPreparation copyWith({
    Object? id = _Undefined,
    String? preparationId,
    int? hireId,
    String? purpose,
    String? signer,
    String? unsignedEnvelopeXdr,
    String? transactionHash,
    int? sequence,
    DateTime? validUntil,
    Object? jobExpiredAt = _Undefined,
    Object? rejectReason = _Undefined,
    DateTime? createdAt,
    Object? supersededAt = _Undefined,
    Object? submittedAt = _Undefined,
  }) {
    return EscrowPreparation(
      id: id is int? ? id : this.id,
      preparationId: preparationId ?? this.preparationId,
      hireId: hireId ?? this.hireId,
      purpose: purpose ?? this.purpose,
      signer: signer ?? this.signer,
      unsignedEnvelopeXdr: unsignedEnvelopeXdr ?? this.unsignedEnvelopeXdr,
      transactionHash: transactionHash ?? this.transactionHash,
      sequence: sequence ?? this.sequence,
      validUntil: validUntil ?? this.validUntil,
      jobExpiredAt: jobExpiredAt is int? ? jobExpiredAt : this.jobExpiredAt,
      rejectReason: rejectReason is String? ? rejectReason : this.rejectReason,
      createdAt: createdAt ?? this.createdAt,
      supersededAt: supersededAt is DateTime?
          ? supersededAt
          : this.supersededAt,
      submittedAt: submittedAt is DateTime? ? submittedAt : this.submittedAt,
    );
  }
}

class EscrowPreparationUpdateTable
    extends _i1.UpdateTable<EscrowPreparationTable> {
  EscrowPreparationUpdateTable(super.table);

  _i1.ColumnValue<String, String> preparationId(String value) =>
      _i1.ColumnValue(
        table.preparationId,
        value,
      );

  _i1.ColumnValue<int, int> hireId(int value) => _i1.ColumnValue(
    table.hireId,
    value,
  );

  _i1.ColumnValue<String, String> purpose(String value) => _i1.ColumnValue(
    table.purpose,
    value,
  );

  _i1.ColumnValue<String, String> signer(String value) => _i1.ColumnValue(
    table.signer,
    value,
  );

  _i1.ColumnValue<String, String> unsignedEnvelopeXdr(String value) =>
      _i1.ColumnValue(
        table.unsignedEnvelopeXdr,
        value,
      );

  _i1.ColumnValue<String, String> transactionHash(String value) =>
      _i1.ColumnValue(
        table.transactionHash,
        value,
      );

  _i1.ColumnValue<int, int> sequence(int value) => _i1.ColumnValue(
    table.sequence,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> validUntil(DateTime value) =>
      _i1.ColumnValue(
        table.validUntil,
        value,
      );

  _i1.ColumnValue<int, int> jobExpiredAt(int? value) => _i1.ColumnValue(
    table.jobExpiredAt,
    value,
  );

  _i1.ColumnValue<String, String> rejectReason(String? value) =>
      _i1.ColumnValue(
        table.rejectReason,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _i1.ColumnValue(
        table.createdAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> supersededAt(DateTime? value) =>
      _i1.ColumnValue(
        table.supersededAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> submittedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.submittedAt,
        value,
      );
}

class EscrowPreparationTable extends _i1.Table<int?> {
  EscrowPreparationTable({super.tableRelation})
    : super(tableName: 'escrow_preparation') {
    updateTable = EscrowPreparationUpdateTable(this);
    preparationId = _i1.ColumnString(
      'preparationId',
      this,
    );
    hireId = _i1.ColumnInt(
      'hireId',
      this,
    );
    purpose = _i1.ColumnString(
      'purpose',
      this,
    );
    signer = _i1.ColumnString(
      'signer',
      this,
    );
    unsignedEnvelopeXdr = _i1.ColumnString(
      'unsignedEnvelopeXdr',
      this,
    );
    transactionHash = _i1.ColumnString(
      'transactionHash',
      this,
    );
    sequence = _i1.ColumnInt(
      'sequence',
      this,
    );
    validUntil = _i1.ColumnDateTime(
      'validUntil',
      this,
    );
    jobExpiredAt = _i1.ColumnInt(
      'jobExpiredAt',
      this,
    );
    rejectReason = _i1.ColumnString(
      'rejectReason',
      this,
    );
    createdAt = _i1.ColumnDateTime(
      'createdAt',
      this,
    );
    supersededAt = _i1.ColumnDateTime(
      'supersededAt',
      this,
    );
    submittedAt = _i1.ColumnDateTime(
      'submittedAt',
      this,
    );
  }

  late final EscrowPreparationUpdateTable updateTable;

  /// Opaque id the client echoes back on submit.
  late final _i1.ColumnString preparationId;

  late final _i1.ColumnInt hireId;

  /// createJob, fund, complete or reject.
  late final _i1.ColumnString purpose;

  /// StrKey of the session wallet that must sign.
  late final _i1.ColumnString signer;

  /// Base64 unsigned TransactionEnvelope XDR, exactly as returned.
  late final _i1.ColumnString unsignedEnvelopeXdr;

  /// Lowercase hex network hash of the prepared transaction.
  late final _i1.ColumnString transactionHash;

  /// Source account sequence number the envelope uses.
  late final _i1.ColumnInt sequence;

  /// End of the envelope time bounds; after it the preparation is expired.
  late final _i1.ColumnDateTime validUntil;

  /// expired_at the create_job was prepared with; bound to the hire when the
  /// job is confirmed.
  late final _i1.ColumnInt jobExpiredAt;

  /// Reject reason baked into a reject envelope.
  late final _i1.ColumnString rejectReason;

  late final _i1.ColumnDateTime createdAt;

  /// Set when a newer preparation replaced this one.
  late final _i1.ColumnDateTime supersededAt;

  /// Set when a submit claimed this preparation.
  late final _i1.ColumnDateTime submittedAt;

  @override
  List<_i1.Column> get columns => [
    id,
    preparationId,
    hireId,
    purpose,
    signer,
    unsignedEnvelopeXdr,
    transactionHash,
    sequence,
    validUntil,
    jobExpiredAt,
    rejectReason,
    createdAt,
    supersededAt,
    submittedAt,
  ];
}

class EscrowPreparationInclude extends _i1.IncludeObject {
  EscrowPreparationInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => EscrowPreparation.t;
}

class EscrowPreparationIncludeList extends _i1.IncludeList {
  EscrowPreparationIncludeList._({
    _i1.WhereExpressionBuilder<EscrowPreparationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EscrowPreparation.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => EscrowPreparation.t;
}

class EscrowPreparationRepository {
  const EscrowPreparationRepository._();

  /// Returns a list of [EscrowPreparation]s matching the given query parameters.
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
  Future<List<EscrowPreparation>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EscrowPreparationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EscrowPreparation>(
      where: where?.call(EscrowPreparation.t),
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [EscrowPreparation] matching the given query parameters.
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
  Future<EscrowPreparation?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? offset,
    _i1.OrderByBuilder<EscrowPreparationTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EscrowPreparation>(
      where: where?.call(EscrowPreparation.t),
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EscrowPreparation] by its [id] or null if no such row exists.
  Future<EscrowPreparation?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<EscrowPreparation>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [EscrowPreparation]s in the list and returns the inserted rows.
  ///
  /// The returned [EscrowPreparation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  Future<List<EscrowPreparation>> insert(
    _i1.DatabaseSession session,
    List<EscrowPreparation> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return session.db.insert<EscrowPreparation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  /// Inserts a single [EscrowPreparation] and returns the inserted row.
  ///
  /// The returned [EscrowPreparation] will have its `id` field set.
  Future<EscrowPreparation> insertRow(
    _i1.DatabaseSession session,
    EscrowPreparation row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<EscrowPreparation>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [EscrowPreparation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<EscrowPreparation>> update(
    _i1.DatabaseSession session,
    List<EscrowPreparation> rows, {
    _i1.ColumnSelections<EscrowPreparationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<EscrowPreparation>(
      rows,
      columns: columns?.call(EscrowPreparation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EscrowPreparation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EscrowPreparation> updateRow(
    _i1.DatabaseSession session,
    EscrowPreparation row, {
    _i1.ColumnSelections<EscrowPreparationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<EscrowPreparation>(
      row,
      columns: columns?.call(EscrowPreparation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [EscrowPreparation] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<EscrowPreparation?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<EscrowPreparationUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<EscrowPreparation>(
      id,
      columnValues: columnValues(EscrowPreparation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EscrowPreparation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<EscrowPreparation>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<EscrowPreparationUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<EscrowPreparationTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _i1.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<EscrowPreparation>(
      columnValues: columnValues(EscrowPreparation.t.updateTable),
      where: where(EscrowPreparation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [EscrowPreparation]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<EscrowPreparation>> delete(
    _i1.DatabaseSession session,
    List<EscrowPreparation> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<EscrowPreparation>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [EscrowPreparation].
  Future<EscrowPreparation> deleteRow(
    _i1.DatabaseSession session,
    EscrowPreparation row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EscrowPreparation>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<EscrowPreparation>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<EscrowPreparationTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<EscrowPreparation>(
      where: where(EscrowPreparation.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<EscrowPreparation>(
      where: where?.call(EscrowPreparation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EscrowPreparation] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<EscrowPreparationTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EscrowPreparation>(
      where: where(EscrowPreparation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
