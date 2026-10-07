/// StellarExpert testnet explorer URL utilities and default contract addresses.
library;

/// Escrow contract of the testnet deployment (PR #84).
const String testnetEscrowContractAddress =
    'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';

/// Raw `PULS3_ESCROW_CONTRACT` dart-define. No default on purpose: a define
/// that is present but empty (`PULS3_ESCROW_CONTRACT=` in a
/// `--dart-define-from-file` .env) would otherwise yield ''.
const String escrowContractOverride = String.fromEnvironment(
  'PULS3_ESCROW_CONTRACT',
);

/// Returns [raw] trimmed, or [testnetEscrowContractAddress] when it is blank.
String resolveEscrowContractAddress(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? testnetEscrowContractAddress : trimmed;
}

/// Escrow contract address shown in the UI: the `PULS3_ESCROW_CONTRACT`
/// dart-define when set, otherwise the testnet deployment.
final String defaultEscrowContractAddress = resolveEscrowContractAddress(
  escrowContractOverride,
);

/// Base URL for StellarExpert on testnet.
const String stellarExpertTestnetBase =
    'https://stellar.expert/explorer/testnet';

/// Returns the testnet transaction explorer URL for [hash].
String stellarExpertTxUrl(String hash) => '$stellarExpertTestnetBase/tx/$hash';

/// Returns the testnet contract explorer URL for [contractId].
String stellarExpertContractUrl(String contractId) =>
    '$stellarExpertTestnetBase/contract/$contractId';
