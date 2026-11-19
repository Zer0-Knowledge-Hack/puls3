/// What a confirmed `create_child_job` proved about one child hire
/// (ADR-0011 D2, D7): the job the contract opened and funded from the
/// parent's reserve, and the payment that funds the child.
final class ChildJobOpening {
  const ChildJobOpening({
    required this.childHireId,
    required this.jobId,
    required this.expiredAt,
    required this.escrow,
    required this.transactionHash,
    required this.payer,
    required this.payee,
    required this.amount,
  });

  final int childHireId;

  /// The child's escrow job id.
  final int jobId;

  /// The child job's `expired_at`, unix seconds.
  final int expiredAt;

  /// StrKey of the escrow contract that holds [jobId].
  final String escrow;

  /// The `create_child_job` transaction hash, lowercase hex. It is also the
  /// child's payment transaction: the same call funds the child job.
  final String transactionHash;

  /// StrKey of the parent agent's wallet, the child job's client.
  final String payer;

  /// StrKey of the subcontracted agent's wallet, the child job's provider.
  final String payee;

  /// USDC stroops drawn from the parent reserve: the child hire's price.
  final int amount;
}

/// The outcome of [ChildJobStore.open].
enum ChildJobOpened {
  /// The child is bound, paid, queued and its receipt line opened.
  opened,

  /// The same opening was applied before; nothing was written.
  alreadyOpened,

  /// The child cannot take this opening: it holds another job or payment,
  /// another hire holds the job id or the transaction, or its receipt line
  /// is no longer `pending`. Nothing was written.
  taken,
}

/// The writes that open a child hire after its `create_child_job` is
/// confirmed (ADR-0011 D7).
abstract interface class ChildJobStore {
  /// In one database transaction: binds [ChildJobOpening.jobId] and its
  /// expiry to the child hire, records its payment, queues its run (#20) and
  /// moves its receipt line from `pending` to the child's status name
  /// (`funded`) with the job id and the transaction. Either every write
  /// lands or none.
  ///
  /// Applying the same opening again answers [ChildJobOpened.alreadyOpened]
  /// without writing, so the run is queued once. Throws [StateError] when the
  /// child hire does not exist.
  Future<ChildJobOpened> open(ChildJobOpening opening);
}
