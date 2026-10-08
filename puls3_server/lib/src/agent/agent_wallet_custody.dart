import 'package:puls3_domain/puls3_domain.dart';

/// Agent wallet custody is not configured (for example the encryption key is
/// missing), so creating an agent wallet is refused instead of storing a
/// secret in the clear.
final class AgentWalletCustodyUnavailable implements Exception {
  const AgentWalletCustodyUnavailable(this.message);

  final String message;

  @override
  String toString() => 'AgentWalletCustodyUnavailable: $message';
}

/// Creates and holds custodied agent wallets (ADR-0003 decision 4).
///
/// The secret is generated and stored encrypted by the adapter; the port only
/// ever exposes the agent's public [StellarAddress].
abstract interface class AgentWalletCustody {
  /// Creates a new agent wallet owned by [owner] and returns its address.
  ///
  /// Throws [AgentWalletCustodyUnavailable] when custody is not configured.
  Future<StellarAddress> create({required StellarAddress owner});
}
