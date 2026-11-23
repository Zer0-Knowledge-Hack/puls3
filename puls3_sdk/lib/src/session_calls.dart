import 'package:puls3_client/puls3_client.dart';

/// The hire calls the SDK makes for the signed-in wallet. They need a
/// session. [Puls3Sdk.connect] backs them with the generated Serverpod
/// client; tests pass a fake.
abstract interface class HireApi {
  /// Creates the hire of [requestId] for [consumer] and prepares its
  /// `create_job` (`HireEndpoint.createHire`).
  Future<CreateHireResult> createHire(
    int agentId,
    String consumer,
    String input,
    String requestId,
  );

  /// The hire [hireId] of [consumer] (`HireEndpoint.getHire`).
  Future<HireDetail> get(int hireId, String consumer);

  /// A fresh unsigned `create_job` for [hireId]
  /// (`HireEndpoint.prepareCreateJob`).
  Future<PreparedTransaction> prepareCreateJob(int hireId);

  /// The unsigned `fund` of hire [hireId] (`HireEndpoint.prepareFund`).
  Future<PreparedTransaction> prepareFund(int hireId);

  /// The unsigned `complete` of hire [hireId]
  /// (`HireEndpoint.prepareComplete`).
  Future<PreparedTransaction> prepareComplete(int hireId);

  /// The unsigned `reject` of hire [hireId] with [reason]
  /// (`HireEndpoint.prepareReject`).
  Future<PreparedTransaction> prepareReject(int hireId, String reason);
}

/// The Studio calls the SDK makes for the signed-in builder. They need a
/// session.
abstract interface class StudioApi {
  /// Runs the saved draft [draftId] once on [input] (`StudioEndpoint.testRun`).
  /// No hire and no payment.
  Future<TestRunResult> testRun(int draftId, String input);

  /// Makes the caller's live Studio agent [hiringAgentId] hire [agentId] on
  /// [input] with its custodied wallet, spending at most [budgetUsdcStroops]
  /// (`StudioEndpoint.hireAgentAs`). The server signs and runs the hire.
  Future<AgentHireStarted> hireAgentAs(
    int hiringAgentId,
    int agentId,
    String input,
    int budgetUsdcStroops,
  );
}

/// [HireApi] over `HireEndpoint` of the generated client.
final class ClientHireApi implements HireApi {
  ClientHireApi(this._client);

  final Client _client;

  @override
  Future<CreateHireResult> createHire(
    int agentId,
    String consumer,
    String input,
    String requestId,
  ) => _client.hire.createHire(agentId, consumer, input, requestId);

  @override
  Future<HireDetail> get(int hireId, String consumer) =>
      _client.hire.getHire(hireId, consumer);

  @override
  Future<PreparedTransaction> prepareCreateJob(int hireId) =>
      _client.hire.prepareCreateJob(hireId);

  @override
  Future<PreparedTransaction> prepareFund(int hireId) =>
      _client.hire.prepareFund(hireId);

  @override
  Future<PreparedTransaction> prepareComplete(int hireId) =>
      _client.hire.prepareComplete(hireId);

  @override
  Future<PreparedTransaction> prepareReject(int hireId, String reason) =>
      _client.hire.prepareReject(hireId, reason);
}

/// [StudioApi] over `StudioEndpoint` of the generated client.
final class ClientStudioApi implements StudioApi {
  ClientStudioApi(this._client);

  final Client _client;

  @override
  Future<TestRunResult> testRun(int draftId, String input) =>
      _client.studio.testRun(draftId, input);

  @override
  Future<AgentHireStarted> hireAgentAs(
    int hiringAgentId,
    int agentId,
    String input,
    int budgetUsdcStroops,
  ) => _client.studio.hireAgentAs(
    hiringAgentId,
    agentId,
    input,
    budgetUsdcStroops,
  );
}

/// A hire or Studio call was made on an SDK that has no session. Nothing was
/// sent to the server.
///
/// A program gets a session from the app ("Copy session for CLI", #259) and
/// passes it to [Puls3Sdk.connect] as `session`.
final class SessionRequired implements Exception {
  const SessionRequired(this.operation);

  /// The SDK method that needs the session, for example `getHire`.
  final String operation;

  @override
  String toString() =>
      'SessionRequired: $operation needs a wallet session (see #259)';
}
