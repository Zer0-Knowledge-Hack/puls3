import 'package:meta/meta.dart';
import 'package:puls3_domain/puls3_domain.dart' hide Hire, Payment;
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'escrow_relay_service.dart';
import 'hire_services.dart';
import 'session_wallet.dart';

/// Creates hires and relays their escrow calls (api.md, `HireEndpoint`).
///
/// Every method first resolves the caller through [SessionWallet.requireLogin]
/// and only then builds the services, so a caller without a session reaches no
/// store and no chain. Wallet parameters must equal the session wallet
/// (`WalletMismatch`), and ownership of a hire is checked against the session
/// wallet by the services.
///
/// `listHires` is not part of this endpoint yet.
///
/// Follow-ups: `InputTooLong` has no documented limit, so the input length is
/// not checked here; `PersistenceUnavailable` is not mapped, so a database
/// failure surfaces as Serverpod's own internal error.
class HireEndpoint extends Endpoint {
  static SessionWallet? _sessionWallet;
  static HireServicesBuilder? _servicesBuilder;
  static HireWiring? _wiring;

  /// A request without an access token is HTTP 401 before the method runs.
  @override
  bool get requireLogin => true;

  static SessionWallet get _wallet =>
      _sessionWallet ?? const WalletSessionWallet();

  /// Replaces the session seam, for tests. `null` restores [WalletSessionWallet].
  @visibleForTesting
  static set sessionWallet(SessionWallet? wallet) => _sessionWallet = wallet;

  /// Replaces how a request's services are built, for tests. `null` restores
  /// the default, which builds them from the `PULS3_*` environment on the
  /// first request that gets past login.
  @visibleForTesting
  static set servicesBuilder(HireServicesBuilder? builder) =>
      _servicesBuilder = builder;

  static HireServices _servicesOn(Session session) {
    final builder = _servicesBuilder;
    if (builder != null) return builder(session);
    return (_wiring ??= HireWiring.fromEnvironment()).servicesOn(session);
  }

  /// Creates the hire of [requestId] for [consumer] and prepares its
  /// `create_job`; repeating the request returns the same hire.
  Future<CreateHireResult> createHire(
    Session session,
    int agentId,
    String consumer,
    String input,
    String requestId,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    _requireSameWallet(wallet, consumer);
    if (agentId < 1) throw Puls3ApiException(code: 'InvalidAgentId');
    try {
      return await _servicesOn(session).hires.createHire(
        agentId: agentId,
        consumer: consumer,
        input: input,
        requestId: requestId,
      );
    } on AgentUnavailable {
      throw Puls3ApiException(code: 'AgentNotFound');
    } on HireRequestInvalid catch (e) {
      throw Puls3ApiException(code: 'InvalidHire', message: e.message);
    } on HireLedgerUnavailable {
      throw Puls3ApiException(code: 'ChainUnavailable');
    }
  }

  /// A fresh unsigned `create_job` for a hire that has no job yet.
  Future<PreparedTransaction> prepareCreateJob(Session session, int hireId) =>
      _prepare(
        session,
        (relay, wallet) => relay.prepareCreateJob(wallet, hireId),
      );

  /// The unsigned `fund` of an open hire.
  Future<PreparedTransaction> prepareFund(Session session, int hireId) =>
      _prepare(session, (relay, wallet) => relay.prepareFund(wallet, hireId));

  /// The unsigned `complete` of a submitted hire.
  Future<PreparedTransaction> prepareComplete(Session session, int hireId) =>
      _prepare(
        session,
        (relay, wallet) => relay.prepareComplete(wallet, hireId),
      );

  /// The unsigned `reject` of a hire, with the consumer's [reason].
  Future<PreparedTransaction> prepareReject(
    Session session,
    int hireId,
    String reason,
  ) => _prepare(
    session,
    (relay, wallet) => relay.prepareReject(wallet, hireId, reason),
  );

  /// The hire [hireId] as its [consumer] sees it: escrow status, run
  /// progress and result (F6). Read-only, so the app polls it.
  Future<HireDetail> getHire(
    Session session,
    int hireId,
    String consumer,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    _requireSameWallet(wallet, consumer);
    final query =
        _servicesOn(session).query ??
        (throw StateError('HireServices has no query service'));
    return query.getHire(wallet, hireId);
  }

  /// Verifies the wallet-signed envelope of [preparationId] and relays it.
  Future<HireDetail> submitEscrowCall(
    Session session,
    int hireId,
    String preparationId,
    String signedTransactionXdr,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    return _servicesOn(session).relay.submitEscrowCall(
      wallet,
      hireId,
      preparationId,
      signedTransactionXdr,
    );
  }

  Future<PreparedTransaction> _prepare(
    Session session,
    Future<PreparedTransaction> Function(
      EscrowRelayService relay,
      StellarAddress wallet,
    )
    call,
  ) async {
    final wallet = await _wallet.requireLogin(session);
    try {
      return await call(_servicesOn(session).relay, wallet);
    } on AgentUnavailable {
      throw Puls3ApiException(code: 'AgentNotFound');
    }
  }

  /// Fails with `InvalidStellarAddress` or `WalletMismatch` unless [address]
  /// is the session [wallet].
  static void _requireSameWallet(StellarAddress wallet, String address) {
    final StellarAddress parsed;
    try {
      parsed = StellarAddress.parse(address);
    } on InvalidStellarAddress {
      throw Puls3ApiException(code: 'InvalidStellarAddress');
    }
    if (parsed != wallet) throw Puls3ApiException(code: 'WalletMismatch');
  }
}
