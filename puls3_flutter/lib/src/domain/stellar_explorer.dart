/// StellarExpert testnet explorer URL utilities and default contract addresses.
library;

/// Deployed Escrow contract address on Stellar testnet (PR #84).
const String defaultEscrowContractAddress =
    'CBRD7A7MXINM7LREKCL3RMKRQ5UMLGKNHAEYY4JT7MVBBB7R5QV4TPE2';

/// Base URL for StellarExpert on testnet.
const String stellarExpertTestnetBase =
    'https://stellar.expert/explorer/testnet';

/// Returns the testnet transaction explorer URL for [hash].
String stellarExpertTxUrl(String hash) => '$stellarExpertTestnetBase/tx/$hash';

/// Returns the testnet contract explorer URL for [contractId].
String stellarExpertContractUrl(String contractId) =>
    '$stellarExpertTestnetBase/contract/$contractId';
