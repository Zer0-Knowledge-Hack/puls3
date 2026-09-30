const stellarTestnetPassphrase = 'Test SDF Network ; September 2015';

class WalletSession {
  const WalletSession({required this.address, required this.networkPassphrase});
  final String address;
  final String networkPassphrase;
}

abstract interface class WalletPort {
  Future<WalletSession> connect();
  Future<String> signTransaction(String transactionXdr);
  Future<String> signAuthEntry(String authorizationEntryXdr);
}

sealed class WalletFailure implements Exception {
  const WalletFailure(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

final class WalletUnavailable extends WalletFailure {
  const WalletUnavailable(super.message);
}

final class WalletRejected extends WalletFailure {
  const WalletRejected(super.message);
}

final class WrongNetwork extends WalletFailure {
  const WrongNetwork(super.message);
}

final class WalletAccountChanged extends WalletFailure {
  const WalletAccountChanged(super.message);
}

final class InvalidEnvelope extends WalletFailure {
  const InvalidEnvelope(super.message);
}

final class ModifiedEnvelope extends WalletFailure {
  const ModifiedEnvelope(super.message);
}

/// The payload binds a different account than the connected wallet session,
/// e.g. a transaction prepared for another payer or an auth entry whose
/// credentials belong to someone else.
final class PayloadAccountMismatch extends WalletFailure {
  const PayloadAccountMismatch(super.message);
}

/// The auth entry uses a credential arm this adapter deliberately does not
/// sign (e.g. protocol-27 ADDRESS_WITH_DELEGATES).
final class UnsupportedAuthCredentials extends WalletFailure {
  const UnsupportedAuthCredentials(super.message);
}
