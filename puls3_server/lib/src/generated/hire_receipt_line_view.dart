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

/// One line of a parent hire's itemized receipt (ADR-0011 D6), as its
/// consumer reads it on `HireDetail.receipt`: one child job paid from the
/// hire's subcontract reserve. The stored row is `HireReceiptLineRecord`.
abstract class HireReceiptLine
    implements _is.SerializableModel, _is.ProtocolSerialization {
  HireReceiptLine._({
    required this.id,
    this.childHireId,
    this.childJobId,
    required this.providerAgentId,
    required this.providerWallet,
    required this.budget,
    this.fee,
    this.payout,
    required this.state,
    this.createTransaction,
    this.createExplorerUrl,
    this.settleTransaction,
    this.settleExplorerUrl,
    this.deliverableHash,
    required this.relatedParty,
    required this.justification,
    required this.createdAt,
  });

  factory HireReceiptLine({
    required int id,
    int? childHireId,
    int? childJobId,
    required int providerAgentId,
    required String providerWallet,
    required int budget,
    int? fee,
    int? payout,
    required String state,
    String? createTransaction,
    String? createExplorerUrl,
    String? settleTransaction,
    String? settleExplorerUrl,
    String? deliverableHash,
    required bool relatedParty,
    required String justification,
    required DateTime createdAt,
  }) = _HireReceiptLineImpl;

  factory HireReceiptLine.fromJson(Map<String, dynamic> jsonSerialization) {
    return HireReceiptLine(
      id: jsonSerialization['id'] as int,
      childHireId: jsonSerialization['childHireId'] as int?,
      childJobId: jsonSerialization['childJobId'] as int?,
      providerAgentId: jsonSerialization['providerAgentId'] as int,
      providerWallet: jsonSerialization['providerWallet'] as String,
      budget: jsonSerialization['budget'] as int,
      fee: jsonSerialization['fee'] as int?,
      payout: jsonSerialization['payout'] as int?,
      state: jsonSerialization['state'] as String,
      createTransaction: jsonSerialization['createTransaction'] as String?,
      createExplorerUrl: jsonSerialization['createExplorerUrl'] as String?,
      settleTransaction: jsonSerialization['settleTransaction'] as String?,
      settleExplorerUrl: jsonSerialization['settleExplorerUrl'] as String?,
      deliverableHash: jsonSerialization['deliverableHash'] as String?,
      relatedParty: _is.BoolJsonExtension.fromJson(
        jsonSerialization['relatedParty'],
      ),
      justification: jsonSerialization['justification'] as String,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int id;

  /// The child hire, once it is stored.
  int? childHireId;

  /// Escrow id of the child job, set once create_child_job is confirmed.
  int? childJobId;

  /// Registry id of the subcontracted agent.
  int providerAgentId;

  /// StrKey of the subcontracted agent's payment wallet.
  String providerWallet;

  /// USDC stroops drawn from the parent reserve as the child budget.
  int budget;

  /// USDC stroops of platform fee, set when the child settles.
  int? fee;

  /// USDC stroops paid to the provider, set when the child settles.
  int? payout;

  /// `pending`, `not_opened`, `unverified`, or the child's HireStatus name:
  /// open, funded, submitted, completed, rejected, expired.
  String state;

  /// The create_child_job transaction hash, lowercase hex.
  String? createTransaction;

  /// StellarExpert link of [createTransaction]; null without one or on a
  /// network StellarExpert does not show.
  String? createExplorerUrl;

  /// The transaction that settled the child, lowercase hex.
  String? settleTransaction;

  /// StellarExpert link of [settleTransaction], like [createExplorerUrl].
  String? settleExplorerUrl;

  /// The child's deliverable hash, lowercase hex, once it is submitted.
  String? deliverableHash;

  /// True when the provider has the same owner as the parent's agent (D10).
  bool relatedParty;

  /// The parent agent's justification of the pick, against the ranking.
  String justification;

  DateTime createdAt;

  /// Returns a shallow copy of this [HireReceiptLine]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  HireReceiptLine copyWith({
    int? id,
    int? childHireId,
    int? childJobId,
    int? providerAgentId,
    String? providerWallet,
    int? budget,
    int? fee,
    int? payout,
    String? state,
    String? createTransaction,
    String? createExplorerUrl,
    String? settleTransaction,
    String? settleExplorerUrl,
    String? deliverableHash,
    bool? relatedParty,
    String? justification,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'HireReceiptLine',
      'id': id,
      if (childHireId != null) 'childHireId': childHireId,
      if (childJobId != null) 'childJobId': childJobId,
      'providerAgentId': providerAgentId,
      'providerWallet': providerWallet,
      'budget': budget,
      if (fee != null) 'fee': fee,
      if (payout != null) 'payout': payout,
      'state': state,
      if (createTransaction != null) 'createTransaction': createTransaction,
      if (createExplorerUrl != null) 'createExplorerUrl': createExplorerUrl,
      if (settleTransaction != null) 'settleTransaction': settleTransaction,
      if (settleExplorerUrl != null) 'settleExplorerUrl': settleExplorerUrl,
      if (deliverableHash != null) 'deliverableHash': deliverableHash,
      'relatedParty': relatedParty,
      'justification': justification,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'HireReceiptLine',
      'id': id,
      if (childHireId != null) 'childHireId': childHireId,
      if (childJobId != null) 'childJobId': childJobId,
      'providerAgentId': providerAgentId,
      'providerWallet': providerWallet,
      'budget': budget,
      if (fee != null) 'fee': fee,
      if (payout != null) 'payout': payout,
      'state': state,
      if (createTransaction != null) 'createTransaction': createTransaction,
      if (createExplorerUrl != null) 'createExplorerUrl': createExplorerUrl,
      if (settleTransaction != null) 'settleTransaction': settleTransaction,
      if (settleExplorerUrl != null) 'settleExplorerUrl': settleExplorerUrl,
      if (deliverableHash != null) 'deliverableHash': deliverableHash,
      'relatedParty': relatedParty,
      'justification': justification,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _HireReceiptLineImpl extends HireReceiptLine {
  _HireReceiptLineImpl({
    required int id,
    int? childHireId,
    int? childJobId,
    required int providerAgentId,
    required String providerWallet,
    required int budget,
    int? fee,
    int? payout,
    required String state,
    String? createTransaction,
    String? createExplorerUrl,
    String? settleTransaction,
    String? settleExplorerUrl,
    String? deliverableHash,
    required bool relatedParty,
    required String justification,
    required DateTime createdAt,
  }) : super._(
         id: id,
         childHireId: childHireId,
         childJobId: childJobId,
         providerAgentId: providerAgentId,
         providerWallet: providerWallet,
         budget: budget,
         fee: fee,
         payout: payout,
         state: state,
         createTransaction: createTransaction,
         createExplorerUrl: createExplorerUrl,
         settleTransaction: settleTransaction,
         settleExplorerUrl: settleExplorerUrl,
         deliverableHash: deliverableHash,
         relatedParty: relatedParty,
         justification: justification,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [HireReceiptLine]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  HireReceiptLine copyWith({
    int? id,
    Object? childHireId = _Undefined,
    Object? childJobId = _Undefined,
    int? providerAgentId,
    String? providerWallet,
    int? budget,
    Object? fee = _Undefined,
    Object? payout = _Undefined,
    String? state,
    Object? createTransaction = _Undefined,
    Object? createExplorerUrl = _Undefined,
    Object? settleTransaction = _Undefined,
    Object? settleExplorerUrl = _Undefined,
    Object? deliverableHash = _Undefined,
    bool? relatedParty,
    String? justification,
    DateTime? createdAt,
  }) {
    return HireReceiptLine(
      id: id ?? this.id,
      childHireId: childHireId is int? ? childHireId : this.childHireId,
      childJobId: childJobId is int? ? childJobId : this.childJobId,
      providerAgentId: providerAgentId ?? this.providerAgentId,
      providerWallet: providerWallet ?? this.providerWallet,
      budget: budget ?? this.budget,
      fee: fee is int? ? fee : this.fee,
      payout: payout is int? ? payout : this.payout,
      state: state ?? this.state,
      createTransaction: createTransaction is String?
          ? createTransaction
          : this.createTransaction,
      createExplorerUrl: createExplorerUrl is String?
          ? createExplorerUrl
          : this.createExplorerUrl,
      settleTransaction: settleTransaction is String?
          ? settleTransaction
          : this.settleTransaction,
      settleExplorerUrl: settleExplorerUrl is String?
          ? settleExplorerUrl
          : this.settleExplorerUrl,
      deliverableHash: deliverableHash is String?
          ? deliverableHash
          : this.deliverableHash,
      relatedParty: relatedParty ?? this.relatedParty,
      justification: justification ?? this.justification,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
