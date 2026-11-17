import 'dart:io';

import 'package:http/http.dart' as http;

import 'clients.dart';
import 'escrow_job.dart';
import 'local_node.dart';
import 'queue.dart';
import 'receipt.dart';
import 'settlement.dart';
import 'verify.dart';

/// One thing the sandbox tries (#296). Each runs on its own local node and
/// its own queue file.
enum SandboxScenario {
  /// Nothing goes wrong.
  happy('the receipt is anchored and verified', ReceiptState.verified),

  /// The node refuses the first two anchors with 429.
  rateLimit('the node answers 429 twice', ReceiptState.verified),

  /// The node is down (503) for the first anchor.
  outage('the node is down for the first anchor', ReceiptState.verified),

  /// The document cannot be read for the first two verifications.
  slowIpfs('the document is not readable at first', ReceiptState.verified),

  /// The process stops after the anchor; a new one finishes the receipt.
  restart('a restart between anchor and verify', ReceiptState.verified),

  /// The gateway serves bytes that do not hash to the CID.
  otherBytes('the gateway serves other bytes', ReceiptState.failed),

  /// The receipt was anchored by a key that is not puls3's.
  otherKey('the receipt was signed by another key', ReceiptState.failed);

  const SandboxScenario(this.title, this.expected);

  final String title;

  /// The state the receipt must end in.
  final ReceiptState expected;
}

/// How one [SandboxScenario] ended.
final class ScenarioResult {
  const ScenarioResult({
    required this.scenario,
    required this.receipt,
    required this.passes,
    required this.requests,
  });

  final SandboxScenario scenario;

  /// The receipt as the queue file holds it at the end.
  final QueuedReceipt receipt;

  /// Queue passes it took.
  final int passes;

  /// What the local node received, as `METHOD path → status`.
  final List<String> requests;

  bool get ok => receipt.state == scenario.expected;
}

/// Runs the receipt queue for the `complete` transaction [txHash] against a
/// local Nirium node, once for each of [scenarios].
///
/// The queue, `NiriumAuditClient` and `IpfsReader` are the real ones and talk
/// HTTP to the node over [nodeClient]. [chain] and [job] read public chain
/// data and are asked once: the answers are reused by every scenario.
///
/// The waits of the queue (15 minutes before verifying, the pause after a
/// failed try) are not slept through. The clock is moved to the moment the
/// receipt is due, so a run takes seconds and still walks the same steps.
Future<List<ScenarioResult>> runSandbox({
  required String txHash,
  required ReceiptSigner signer,
  required SettlementLookup chain,
  required JobLookup job,
  required http.Client nodeClient,
  required Directory directory,
  Iterable<SandboxScenario> scenarios = SandboxScenario.values,
  AnchorMode mode = AnchorMode.record,
  void Function(String line)? log,
}) async {
  final say = log ?? (_) {};
  EscrowSettlement? settlement;
  Future<EscrowSettlement> chainOnce(String tx) async =>
      settlement ??= await chain(tx);
  final jobs = <String, EscrowJob>{};
  Future<EscrowJob> jobOnce(String escrow, String jobId) async =>
      jobs['$escrow/$jobId'] ??= await job(escrow, jobId);

  directory.createSync(recursive: true);
  final results = <ScenarioResult>[];
  for (final scenario in scenarios) {
    say('');
    say('== ${scenario.name}: ${scenario.title}');
    final node = await LocalNiriumNode.start();
    final file = File('${directory.path}/${scenario.name}.json');
    if (file.existsSync()) file.deleteSync();
    var clock = DateTime.now().toUtc();

    ReceiptQueue queue(ReceiptSigner as) => ReceiptQueue(
      store: FileReceiptStore(file),
      signer: as,
      chain: chainOnce,
      job: jobOnce,
      anchor: NiriumAuditClient(nodeClient, node: node.url).anchor,
      read: IpfsReader(nodeClient, gateways: [node.gateway]).read,
      now: () => clock,
      mode: mode,
      tag: 'puls3-sandbox',
    );

    try {
      switch (scenario) {
        case SandboxScenario.rateLimit:
          node.rateLimitNext = 2;
        case SandboxScenario.outage:
          node.unavailableNext = 1;
        case SandboxScenario.slowIpfs:
          node.holdDocuments = true;
        case SandboxScenario.otherBytes:
          node.serveOtherBytes = true;
        case SandboxScenario.happy ||
            SandboxScenario.restart ||
            SandboxScenario.otherKey:
          break;
      }

      // Another key anchors; puls3's own key then has to refuse it.
      var current = queue(
        scenario == SandboxScenario.otherKey ? ReceiptSigner.random() : signer,
      );
      await current.enqueue(txHash);

      var passes = 0;
      late QueuedReceipt receipt;
      while (true) {
        passes++;
        final changed = await current.runOnce();
        receipt = (await FileReceiptStore(file).all()).single;
        for (final r in changed) {
          say(
            '  pass $passes: ${r.state.name}'
            '${r.cid == null ? '' : ' ${r.cid}'}'
            '${r.reason == null ? '' : ' (${r.reason})'}',
          );
        }
        if (receipt.state == ReceiptState.verified ||
            receipt.state == ReceiptState.failed ||
            passes >= 40) {
          break;
        }
        if (receipt.state == ReceiptState.anchored) {
          if (scenario == SandboxScenario.slowIpfs && receipt.attempts >= 2) {
            node.holdDocuments = false;
          }
          if (scenario == SandboxScenario.restart ||
              scenario == SandboxScenario.otherKey) {
            // A new process: a new store and a new queue over the same file.
            current = queue(signer);
          }
        }
        // Wait, without sleeping, until the receipt is due.
        if (receipt.notBefore.isAfter(clock)) clock = receipt.notBefore;
      }

      final result = ScenarioResult(
        scenario: scenario,
        receipt: receipt,
        passes: passes,
        requests: List.of(node.log),
      );
      say(
        '  ${result.ok ? 'ok' : 'UNEXPECTED'}: ended ${receipt.state.name}, '
        'expected ${scenario.expected.name} '
        '(${node.log.length} requests to the local node)',
      );
      results.add(result);
    } finally {
      await node.close();
    }
  }
  return results;
}
