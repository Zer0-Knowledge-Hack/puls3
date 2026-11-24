import 'package:puls3_client/puls3_client.dart';

import 'hire_gateway.dart';

/// Maps `HireDetail.receipt` (#334, ADR-0011 D6) to the app's receipt
/// entries, oldest first as the server sends them; null is no lines. Both the
/// consumer's `getHire` and the builder's `getAgentHire` use it.
List<HireReceiptEntry> hireReceiptEntries(List<HireReceiptLine>? lines) => [
  for (final line in lines ?? const <HireReceiptLine>[])
    HireReceiptEntry(
      id: line.id,
      childHireId: line.childHireId,
      childJobId: line.childJobId,
      providerAgentId: line.providerAgentId,
      providerWallet: line.providerWallet,
      budgetUsdcStroops: line.budget,
      feeUsdcStroops: line.fee,
      payoutUsdcStroops: line.payout,
      state: line.state,
      createTransaction: line.createTransaction,
      createExplorerUrl: line.createExplorerUrl,
      settleTransaction: line.settleTransaction,
      settleExplorerUrl: line.settleExplorerUrl,
      deliverableHash: line.deliverableHash,
      relatedParty: line.relatedParty,
      justification: line.justification,
      createdAt: line.createdAt,
    ),
];
