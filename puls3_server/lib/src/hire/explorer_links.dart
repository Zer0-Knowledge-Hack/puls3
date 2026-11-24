import '../ledger/stellar_config.dart';

/// Builds the explorer link of one transaction hash.
typedef TransactionUrl = String Function(String transactionHash);

/// The Stellar public network passphrase.
const _publicPassphrase = 'Public Global Stellar Network ; September 2015';

/// StellarExpert transaction links for the network of [networkPassphrase]
/// (testnet or public), or `null` for a network StellarExpert does not show,
/// so no link points at the wrong chain.
TransactionUrl? stellarExpertTransactionUrls(String networkPassphrase) {
  final network = switch (networkPassphrase) {
    _ when networkPassphrase == StellarConfig.testnet.networkPassphrase =>
      'testnet',
    _publicPassphrase => 'public',
    _ => null,
  };
  if (network == null) return null;
  return (hash) => 'https://stellar.expert/explorer/$network/tx/$hash';
}
