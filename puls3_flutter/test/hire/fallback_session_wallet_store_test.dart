import 'package:flutter_test/flutter_test.dart';
import 'package:puls3_flutter/src/hire/wallet_session.dart';

/// Storage like the browser's `localStorage`, which can refuse a write when
/// it is full or blocked (QuotaExceededError, some private modes).
class _Storage implements SessionWalletStorage {
  String? item;
  bool refuseWrites = false;
  bool refuseReads = false;

  @override
  String? getItem() {
    if (refuseReads) throw StateError('SecurityError');
    return item;
  }

  @override
  void setItem(String wallet) {
    if (refuseWrites) throw StateError('QuotaExceededError');
    item = wallet;
  }

  @override
  void removeItem() {
    if (refuseWrites) throw StateError('QuotaExceededError');
    item = null;
  }
}

void main() {
  late _Storage storage;
  late FallbackSessionWalletStore store;

  setUp(() {
    storage = _Storage();
    store = FallbackSessionWalletStore(storage);
  });

  test('a wallet is kept in storage, so a reload still knows it', () async {
    await store.write('GUSER123');

    expect(storage.item, 'GUSER123');
    expect(await store.read(), 'GUSER123');
    expect(await FallbackSessionWalletStore(storage).read(), 'GUSER123');

    await store.write(null);
    expect(storage.item, isNull);
    expect(await store.read(), isNull);
  });

  test(
    'a refused write is still read back for the rest of the visit',
    () async {
      storage.refuseWrites = true;

      await store.write('GUSER123');

      expect(storage.item, isNull);
      expect(await store.read(), 'GUSER123');
    },
  );

  test('a refused removal never brings back the signed-out wallet', () async {
    await store.write('GUSER123');
    storage.refuseWrites = true;

    await store.write(null);

    expect(storage.item, 'GUSER123');
    expect(await store.read(), isNull);
  });

  test('a refused read falls back to memory', () async {
    storage.refuseReads = true;

    await store.write('GUSER123');

    expect(await store.read(), 'GUSER123');
  });

  test('without storage it keeps the wallet in memory', () async {
    final memory = FallbackSessionWalletStore(null);

    await memory.write('GUSER123');

    expect(await memory.read(), 'GUSER123');
  });
}
