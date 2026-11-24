import 'package:puls3_domain/puls3_domain.dart' show HireStatus;
import 'package:puls3_server/src/hire/hire_lifecycle_store.dart';
import 'package:puls3_server/src/hire/hire_receipt_store.dart';
import 'package:puls3_server/src/hire/open_children.dart';
import 'package:test/test.dart';

import '../support/in_memory_hire_lifecycle_store.dart';
import '../support/in_memory_hire_receipt_store.dart';

const _alice = 'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H';
const _agentA = 'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY';
const _agentB = 'GBRPYHIL2CI3FNQ4BXLFMNDLFJUNPU2HY3ZMFSHONUCEOASW7QC7OX2H';

void main() {
  late InMemoryHireLifecycleStore hires;
  late InMemoryHireReceiptStore receipts;
  late OpenChildren open;
  late int parentHireId;
  var children = 0;

  Future<int> child({String? lineState}) async {
    children++;
    final row = await hires.insertHire(
      NewHire(
        consumer: _agentA,
        agentId: 9,
        price: 500000,
        manifestVersion: 1,
        expiredAt: 1791747914,
        requestId: 'child:$parentHireId:call-$children',
        input: 'research',
        parentHireId: parentHireId,
      ),
    );
    await receipts.insert(
      NewReceiptLine(
        parentHireId: parentHireId,
        childHireId: row.id,
        providerAgentId: 9,
        providerWallet: _agentB,
        budget: 500000,
        relatedParty: false,
        justification: 'j',
      ),
    );
    if (lineState == ReceiptLineState.notOpened) {
      await receipts.markNotOpened(row.id);
    } else if (lineState == ReceiptLineState.unverified) {
      await receipts.markUnverified(row.id);
    }
    return row.id;
  }

  setUp(() async {
    hires = InMemoryHireLifecycleStore();
    receipts = InMemoryHireReceiptStore();
    open = OpenChildren(receipts: receipts, hires: hires);
    children = 0;
    parentHireId = (await hires.insertHire(
      const NewHire(
        consumer: _alice,
        agentId: 7,
        price: 5000000,
        manifestVersion: 1,
        expiredAt: 1791947914,
        requestId: 'parent',
        input: 'summarise',
        subcontractReserve: 2000000,
      ),
    )).id;
  });

  test('a hire without children has none open', () async {
    expect(await open.anyOpen(parentHireId), isFalse);
  });

  test('a pending, unverified, funded or submitted child is open', () async {
    for (final status in [null, HireStatus.funded, HireStatus.submitted]) {
      final id = await child();
      hires.statusOverride[id] = status;
      expect(await open.anyOpen(parentHireId), isTrue, reason: '$status');
      hires.statusOverride[id] = HireStatus.completed;
    }
    await child(lineState: ReceiptLineState.unverified);
    expect(await open.anyOpen(parentHireId), isTrue);
  });

  test('children that never opened or settled are closed', () async {
    await child(lineState: ReceiptLineState.notOpened);
    for (final status in [
      HireStatus.completed,
      HireStatus.rejected,
      HireStatus.expired,
    ]) {
      hires.statusOverride[await child()] = status;
    }

    expect(await open.anyOpen(parentHireId), isFalse);
  });
}
