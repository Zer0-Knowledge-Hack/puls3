import 'entities.dart';
import 'stellar_address.dart';
import 'values.dart';

/// The escrow contract's state for a job (ADR-0005).
enum JobState { open, funded, submitted, completed, rejected, expired }

/// A job as the escrow contract reports it (`get_job`). Plain chain facts:
/// [verifyFunding] decides whether they pay a hire.
final class FundedJob {
  const FundedJob({
    required this.jobId,
    required this.client,
    required this.evaluator,
    required this.provider,
    required this.token,
    required this.agentId,
    required this.budget,
    required this.expiredAt,
    required this.state,
  });

  final int jobId;
  final StellarAddress client;
  final StellarAddress evaluator;
  final StellarAddress provider;
  final StellarAddress token;
  final AgentId agentId;

  /// The escrowed amount in stroops. A `BigInt` because the contract's `i128`
  /// can exceed [UsdcAmount.maxStroops]; [verifyFunding] bounds it.
  final BigInt budget;

  /// Unix seconds.
  final int expiredAt;
  final JobState state;
}

/// Which job field does not match the hire. [field] is the escrow's name for
/// it, reported as `details.field` of `JobMismatch` (api.md, funding
/// verification).
enum FundingRejection {
  jobNotFunded('state'),
  clientMismatch('client'),
  evaluatorMismatch('evaluator'),
  wrongDestination('provider'),
  agentMismatch('agent_id'),
  wrongAsset('token'),
  amountMismatch('budget'),
  expiryMismatch('expired_at');

  const FundingRejection(this.field);

  final String field;
}

sealed class FundingVerdict {
  const FundingVerdict();
}

/// The funding pays the hire: [payment] is ready for `Hire.fund`.
final class FundingAccepted extends FundingVerdict {
  const FundingAccepted(this.payment);

  final Payment payment;
}

final class FundingRejected extends FundingVerdict {
  const FundingRejected(this.reason);

  final FundingRejection reason;
}

/// Decides whether [job], funded by [transaction], pays [hire].
///
/// Pure. It applies the job-field checks of `docs/architecture/api.md`:
/// state exactly `Funded`; client and evaluator are the hire consumer;
/// provider is [agentWallet]; token is [usdc]; budget is the hire price;
/// `expired_at` is [expiredAt], the value the server prepared `create_job`
/// with. The agent id is checked too. The first failing check wins.
///
/// The transaction status, the funding event and the job read are the
/// caller's evidence; a job id already bound to another hire needs storage
/// and also belongs to the caller. The fee is never checked: the consumer
/// bounds it with `max_fee_bps` when it signs `fund` (ADR-0005 D7).
FundingVerdict verifyFunding(
  Hire hire,
  FundedJob job, {
  required TransactionHash transaction,
  required StellarAddress usdc,
  required StellarAddress agentWallet,
  required int expiredAt,
}) {
  if (job.state != JobState.funded) {
    return const FundingRejected(FundingRejection.jobNotFunded);
  }
  if (job.client != hire.consumer) {
    return const FundingRejected(FundingRejection.clientMismatch);
  }
  if (job.evaluator != hire.consumer) {
    return const FundingRejected(FundingRejection.evaluatorMismatch);
  }
  if (job.provider != agentWallet) {
    return const FundingRejected(FundingRejection.wrongDestination);
  }
  if (job.agentId != hire.agentId) {
    return const FundingRejected(FundingRejection.agentMismatch);
  }
  if (job.token != usdc) {
    return const FundingRejected(FundingRejection.wrongAsset);
  }
  final budget = _stroops(job.budget);
  if (budget == null || budget != hire.price) {
    return const FundingRejected(FundingRejection.amountMismatch);
  }
  if (job.expiredAt != expiredAt) {
    return const FundingRejected(FundingRejection.expiryMismatch);
  }
  return FundingAccepted(
    Payment(
      transaction: transaction,
      hireId: hire.id,
      payer: job.client,
      payee: job.provider,
      amount: budget,
    ),
  );
}

/// [value] as an amount, or `null` when it is outside `UsdcAmount`'s range.
UsdcAmount? _stroops(BigInt value) {
  if (value < BigInt.zero || value > BigInt.from(UsdcAmount.maxStroops)) {
    return null;
  }
  return UsdcAmount.stroops(value.toInt());
}
