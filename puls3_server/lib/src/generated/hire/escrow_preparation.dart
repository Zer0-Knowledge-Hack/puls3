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

/// One unsigned escrow envelope the server prepared for a session wallet.
/// Kept so that submit can verify the signed envelope against the exact
/// prepared bytes, and so a newer preparation can supersede an older one.
abstract class EscrowPreparation
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
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
      validUntil: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['validUntil'],
      ),
      jobExpiredAt: jsonSerialization['jobExpiredAt'] as int?,
      rejectReason: jsonSerialization['rejectReason'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      supersededAt: jsonSerialization['supersededAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['supersededAt'],
            ),
      submittedAt: jsonSerialization['submittedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
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
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [EscrowPreparation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
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
    _is.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _is.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    EscrowPreparationInclude? include,
  }) {
    return EscrowPreparationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
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
  @_is.useResult
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
    extends _is.UpdateTable<EscrowPreparationTable> {
  EscrowPreparationUpdateTable(super.table);

  _is.ColumnValue<String, String> preparationId(String value) =>
      _is.ColumnValue(
        table.preparationId,
        value,
      );

  _is.ColumnValue<int, int> hireId(int value) => _is.ColumnValue(
    table.hireId,
    value,
  );

  _is.ColumnValue<String, String> purpose(String value) => _is.ColumnValue(
    table.purpose,
    value,
  );

  _is.ColumnValue<String, String> signer(String value) => _is.ColumnValue(
    table.signer,
    value,
  );

  _is.ColumnValue<String, String> unsignedEnvelopeXdr(String value) =>
      _is.ColumnValue(
        table.unsignedEnvelopeXdr,
        value,
      );

  _is.ColumnValue<String, String> transactionHash(String value) =>
      _is.ColumnValue(
        table.transactionHash,
        value,
      );

  _is.ColumnValue<int, int> sequence(int value) => _is.ColumnValue(
    table.sequence,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> validUntil(DateTime value) =>
      _is.ColumnValue(
        table.validUntil,
        value,
      );

  _is.ColumnValue<int, int> jobExpiredAt(int? value) => _is.ColumnValue(
    table.jobExpiredAt,
    value,
  );

  _is.ColumnValue<String, String> rejectReason(String? value) =>
      _is.ColumnValue(
        table.rejectReason,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> supersededAt(DateTime? value) =>
      _is.ColumnValue(
        table.supersededAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> submittedAt(DateTime? value) =>
      _is.ColumnValue(
        table.submittedAt,
        value,
      );
}

class EscrowPreparationTable extends _is.Table<int?> {
  EscrowPreparationTable({super.tableRelation})
    : super(tableName: 'escrow_preparation') {
    updateTable = EscrowPreparationUpdateTable(this);
    preparationId = _is.ColumnString(
      'preparationId',
      this,
    );
    hireId = _is.ColumnInt(
      'hireId',
      this,
    );
    purpose = _is.ColumnString(
      'purpose',
      this,
    );
    signer = _is.ColumnString(
      'signer',
      this,
    );
    unsignedEnvelopeXdr = _is.ColumnString(
      'unsignedEnvelopeXdr',
      this,
    );
    transactionHash = _is.ColumnString(
      'transactionHash',
      this,
    );
    sequence = _is.ColumnInt(
      'sequence',
      this,
    );
    validUntil = _is.ColumnDateTime(
      'validUntil',
      this,
    );
    jobExpiredAt = _is.ColumnInt(
      'jobExpiredAt',
      this,
    );
    rejectReason = _is.ColumnString(
      'rejectReason',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    supersededAt = _is.ColumnDateTime(
      'supersededAt',
      this,
    );
    submittedAt = _is.ColumnDateTime(
      'submittedAt',
      this,
    );
  }

  late final EscrowPreparationUpdateTable updateTable;

  /// Opaque id the client echoes back on submit.
  late final _is.ColumnString preparationId;

  late final _is.ColumnInt hireId;

  /// createJob, fund, complete or reject.
  late final _is.ColumnString purpose;

  /// StrKey of the session wallet that must sign.
  late final _is.ColumnString signer;

  /// Base64 unsigned TransactionEnvelope XDR, exactly as returned.
  late final _is.ColumnString unsignedEnvelopeXdr;

  /// Lowercase hex network hash of the prepared transaction.
  late final _is.ColumnString transactionHash;

  /// Source account sequence number the envelope uses.
  late final _is.ColumnInt sequence;

  /// End of the envelope time bounds; after it the preparation is expired.
  late final _is.ColumnDateTime validUntil;

  /// expired_at the create_job was prepared with; bound to the hire when the
  /// job is confirmed.
  late final _is.ColumnInt jobExpiredAt;

  /// Reject reason baked into a reject envelope.
  late final _is.ColumnString rejectReason;

  late final _is.ColumnDateTime createdAt;

  /// Set when a newer preparation replaced this one.
  late final _is.ColumnDateTime supersededAt;

  /// Set when a submit claimed this preparation.
  late final _is.ColumnDateTime submittedAt;

  @override
  List<_is.Column> get columns => [
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

class EscrowPreparationInclude extends _is.IncludeObject {
  EscrowPreparationInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => EscrowPreparation.t;
}

class EscrowPreparationIncludeList extends _is.IncludeList {
  EscrowPreparationIncludeList._({
    _is.WhereExpressionBuilder<EscrowPreparationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(EscrowPreparation.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => EscrowPreparation.t;
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
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _is.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<EscrowPreparation>(
      where: where?.call(EscrowPreparation.t),
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
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
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? offset,
    _is.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _is.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<EscrowPreparation>(
      where: where?.call(EscrowPreparation.t),
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [EscrowPreparation] by its [id] or null if no such row exists.
  Future<EscrowPreparation?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
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
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EscrowPreparation>> insert(
    _is.DatabaseSession session,
    List<EscrowPreparation> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<EscrowPreparation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [EscrowPreparation] and returns the inserted row.
  ///
  /// The returned [EscrowPreparation] will have its `id` field set.
  Future<EscrowPreparation> insertRow(
    _is.DatabaseSession session,
    EscrowPreparation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<EscrowPreparation>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [EscrowPreparation]s in the list and returns the resulting rows.
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
  /// The returned [EscrowPreparation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EscrowPreparation>> upsert(
    _is.DatabaseSession session,
    List<EscrowPreparation> rows, {
    required _is.ColumnSelections<EscrowPreparationTable> conflictColumns,
    _is.ColumnSelections<EscrowPreparationTable>? updateColumns,
    _is.WhereExpressionBuilder<EscrowPreparationTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<EscrowPreparation>(
      rows,
      conflictColumns: conflictColumns(EscrowPreparation.t),
      updateColumns: updateColumns?.call(EscrowPreparation.t),
      updateWhere: updateWhere?.call(EscrowPreparation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [EscrowPreparation] and returns the resulting row.
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
  /// The returned [EscrowPreparation] will have its `id` field set.
  Future<EscrowPreparation?> upsertRow(
    _is.DatabaseSession session,
    EscrowPreparation row, {
    required _is.ColumnSelections<EscrowPreparationTable> conflictColumns,
    _is.ColumnSelections<EscrowPreparationTable>? updateColumns,
    _is.WhereExpressionBuilder<EscrowPreparationTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<EscrowPreparation>(
      row,
      conflictColumns: conflictColumns(EscrowPreparation.t),
      updateColumns: updateColumns?.call(EscrowPreparation.t),
      updateWhere: updateWhere?.call(EscrowPreparation.t),
      transaction: transaction,
    );
  }

  /// Updates all [EscrowPreparation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EscrowPreparation>> update(
    _is.DatabaseSession session,
    List<EscrowPreparation> rows, {
    _is.ColumnSelections<EscrowPreparationTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<EscrowPreparation>(
      rows,
      columns: columns?.call(EscrowPreparation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [EscrowPreparation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<EscrowPreparation> updateRow(
    _is.DatabaseSession session,
    EscrowPreparation row, {
    _is.ColumnSelections<EscrowPreparationTable>? columns,
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<EscrowPreparationUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<EscrowPreparation>(
      id,
      columnValues: columnValues(EscrowPreparation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [EscrowPreparation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<EscrowPreparation>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<EscrowPreparationUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<EscrowPreparationTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _is.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<EscrowPreparation>(
      columnValues: columnValues(EscrowPreparation.t.updateTable),
      where: where(EscrowPreparation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [EscrowPreparation]s in the list and returns the deleted rows.
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
  Future<List<EscrowPreparation>> delete(
    _is.DatabaseSession session,
    List<EscrowPreparation> rows, {
    _is.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _is.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<EscrowPreparation>(
      rows,
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [EscrowPreparation].
  Future<EscrowPreparation> deleteRow(
    _is.DatabaseSession session,
    EscrowPreparation row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<EscrowPreparation>(
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
  Future<List<EscrowPreparation>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EscrowPreparationTable> where,
    _is.OrderByBuilder<EscrowPreparationTable>? orderBy,
    _is.OrderByListBuilder<EscrowPreparationTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<EscrowPreparation>(
      where: where(EscrowPreparation.t),
      orderBy: orderBy?.call(EscrowPreparation.t),
      orderByList: orderByList?.call(EscrowPreparation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<EscrowPreparationTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<EscrowPreparation>(
      where: where?.call(EscrowPreparation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [EscrowPreparation] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<EscrowPreparationTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<EscrowPreparation>(
      where: where(EscrowPreparation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
