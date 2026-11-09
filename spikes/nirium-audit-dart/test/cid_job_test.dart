import 'dart:convert';

import 'package:nirium_audit_spike/nirium_audit.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('cidV0ForFile', () {
    test('recomputes the CIDs Nirium returned on 2026-11-07', () {
      expect(cidV0ForFile(served(recordCid)), recordCid);
      expect(cidV0ForFile(served(hashCid)), hashCid);
    });

    test('a one-byte change gives another CID', () {
      final bytes = [...served(recordCid)];
      bytes[bytes.length - 2] ^= 1;
      expect(cidV0ForFile(bytes), isNot(recordCid));
    });

    test('a known empty-file CID', () {
      // `ipfs add` of an empty file.
      expect(
        cidV0ForFile([]),
        'QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH',
      );
    });

    test('a file above one block is refused', () {
      expect(
        () => cidV0ForFile(List.filled(maxSingleBlockFile + 1, 0)),
        throwsArgumentError,
      );
    });
  });

  group('escrow job', () {
    test('job 3 binds agent #7 to the wallet the escrow paid', () {
      final job = job3Job();
      expect(job.agentId, 7);
      expect(job.provider, ledgerScoutWallet);
      expect(job.state, EscrowJob.completed);
    });

    test('the ledger key is DataKey::Job(3) on the escrow', () {
      expect(
        jobLedgerKey(escrow, '3'),
        'AAAABgAAAAFiP4PsuhrPriRQl7ixUYdoxZlNOAmMcTP7KhCH8ewryQAAABAAAAABAAAAAgAAAA8AAAADSm9iAAAAAAUAAAAAAAAAAwAAAAE=',
      );
    });

    test('an entry that is not a job is refused', () {
      final notJob = base64Encode([0, 0, 0, 0]);
      expect(() => escrowJobFromEntry(notJob), throwsA(anything));
    });
  });
}
