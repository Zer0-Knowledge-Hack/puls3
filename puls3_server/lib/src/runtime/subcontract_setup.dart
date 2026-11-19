import 'agent_runner.dart';
import 'run_manifest.dart';
import 'subcontract_port.dart';
import 'subcontract_tools.dart';
import 'tool_loop.dart';

/// Tells a paused run what became of its child hire (ADR-0011 D8). T6
/// implements it on the child hire's escrow job and run; until then it is
/// not wired in production and tests fake it.
abstract interface class ChildResultSource {
  /// The child's result, or `null` while hire [childHireId] has neither
  /// delivered nor ended. A thrown error leaves the run waiting for a later
  /// pass.
  Future<ChildToolResult?> resultOf(int childHireId);
}

/// Runs [body] on the [AgentRunner] that [manifest] runs on: the team runner
/// for a seeded manifest, a runner on the builder's credential for an
/// `OwnedRunManifest` (`runnerLease` in `run_execution.dart`). The runner
/// is valid only inside [body].
typedef RunnerLease =
    Future<LoopOutcome> Function(
      RunManifest manifest,
      Future<LoopOutcome> Function(AgentRunner runner) body,
    );

/// What `HireRunner` needs to run opted-in manifests through the tool loop
/// and to resume paused runs. Without it every run is one plain segment.
final class SubcontractSetup {
  const SubcontractSetup({
    required this.search,
    required this.port,
    required this.children,
    this.lease,
    this.maxTurns = defaultMaxLoopTurns,
  });

  /// The marketplace search behind `search_agents`.
  final AgentSearch search;

  /// Opens a child hire for `subcontract`.
  final SubcontractPort port;

  /// Reports a paused run's child result.
  final ChildResultSource children;

  /// Where the loop runs; `null` runs every manifest on the runner's team
  /// [AgentRunner].
  final RunnerLease? lease;

  /// See [ToolLoop.maxTurns].
  final int maxTurns;
}
