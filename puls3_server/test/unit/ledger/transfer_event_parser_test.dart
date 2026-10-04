import 'dart:convert';
import 'dart:io';

import 'package:puls3_domain/puls3_domain.dart';
import 'package:puls3_server/src/ledger/stellar_config.dart';
import 'package:puls3_server/src/ledger/transfer_event_parser.dart';
import 'package:test/test.dart';

final _usdcSac = StellarConfig.testnet.usdcSac;
final _hash = TransactionHash.parse(
  '652a575b5d85814c19a4fed0f7d21f40acb35a399c4008d450877ee83e8b31ab',
);

/// A deep copy of the recorded `result`, so a test can mutate it freely.
Map<String, Object?> _recorded([String name = 'get_transaction_success.json']) {
  final response =
      jsonDecode(File('test/unit/ledger/fixtures/$name').readAsStringSync())
          as Map<String, Object?>;
  return response['result']! as Map<String, Object?>;
}

/// The recorded USDC transfer event of [tx].
Map<String, Object?> _event(Map<String, Object?> tx) {
  final events = (tx['events']! as Map)['contractEventsJson']! as List;
  return (events.single as List).single as Map<String, Object?>;
}

Map<String, Object?> _v0(Map<String, Object?> event) =>
    (event['body']! as Map)['v0']! as Map<String, Object?>;

List<Object?> _dataMap(Map<String, Object?> event) =>
    (_v0(event)['data']! as Map)['map']! as List<Object?>;

Map<String, Object?> _entry(Map<String, Object?> event, String symbol) =>
    _dataMap(event).cast<Map<String, Object?>>().firstWhere(
      (e) => (e['key']! as Map)['symbol'] == symbol,
    );

Map<String, Object?> _copy(Map<String, Object?> event) =>
    jsonDecode(jsonEncode(event)) as Map<String, Object?>;

Payment? _parse(Map<String, Object?> tx) =>
    firstUsdcPayment(tx, transaction: _hash, usdcSac: _usdcSac);

void main() {
  group('the recorded payment', () {
    test('is read into a Payment', () {
      final payment = _parse(_recorded());

      expect(payment, isNotNull);
      expect(payment!.transaction, _hash);
      expect(payment.hireId, HireId(8));
      expect(payment.amount, UsdcAmount.stroops(5000000));
      expect(
        payment.payer,
        StellarAddress.parse(
          'GABKNX5HWXUYTWF6ORIKYO2NHTAPJ67OIF46TPP2IEMVGWXGBQXIHF5H',
        ),
      );
      expect(
        payment.payee,
        StellarAddress.parse(
          'GAFUYV5G3SBKIPAFDVAKZVGYNJY3YCMO2KD6OXTU2KYCIEMTM3SMIFKY',
        ),
      );
    });

    test('is read from a flat event list and from a tree walk', () {
      final flat = _recorded();
      (flat['events']! as Map<String, Object?>)['contractEventsJson'] = [
        _event(_recorded()),
      ];
      final walked = _recorded();
      (walked['events']! as Map<String, Object?>).remove('contractEventsJson');
      (walked['events']! as Map<String, Object?>)['elsewhere'] = {
        'nested': [_event(_recorded())],
      };

      expect(_parse(flat)?.hireId, HireId(8));
      expect(_parse(walked)?.hireId, HireId(8));
    });
  });

  group('not a payment', () {
    test('a FAILED transaction', () {
      final tx = _recorded()..['status'] = 'FAILED';

      expect(_parse(tx), isNull);
    });

    test('a NOT_FOUND transaction', () {
      expect(_parse(_recorded('get_transaction_not_found.json')), isNull);
    });

    test('a transaction with no status', () {
      final tx = _recorded()..remove('status');

      expect(_parse(tx), isNull);
    });

    test('a transfer from a contract other than the USDC SAC', () {
      final tx = _recorded();
      _event(tx)['contract_id'] = StellarConfig.testnet.escrow.value;

      expect(_parse(tx), isNull);
    });

    test('an event that is not a transfer', () {
      final tx = _recorded();
      (_v0(_event(tx))['topics']! as List)[0] = {'symbol': 'mint'};

      expect(_parse(tx), isNull);
    });

    test('a destination without a muxed id', () {
      final tx = _recorded();
      final data = _v0(_event(tx))['data']! as Map<String, Object?>;
      data['map'] = _dataMap(_event(tx))
          .cast<Map<String, Object?>>()
          .where((e) => (e['key']! as Map)['symbol'] != 'to_muxed_id')
          .toList();

      expect(_parse(tx), isNull);
    });

    test('a bare amount instead of a map', () {
      final tx = _recorded();
      _v0(_event(tx))['data'] = {'i128': '5000000'};

      expect(_parse(tx), isNull);
    });

    for (final amount in ['0', '-1', '9007199254740992']) {
      test('an amount of $amount', () {
        final tx = _recorded();
        _entry(_event(tx), 'amount')['val'] = {'i128': amount};

        expect(_parse(tx), isNull);
      });
    }

    test('the largest accepted amount is still a payment', () {
      final tx = _recorded();
      _entry(_event(tx), 'amount')['val'] = {'i128': '9007199254740991'};

      expect(_parse(tx)?.amount, UsdcAmount.stroops(9007199254740991));
    });

    test('a hire id of 0', () {
      final tx = _recorded();
      _entry(_event(tx), 'to_muxed_id')['val'] = {'u64': '0'};

      expect(_parse(tx), isNull);
    });

    test('a hire id above 2^53 - 1', () {
      final tx = _recorded();
      _entry(_event(tx), 'to_muxed_id')['val'] = {'u64': '9007199254740992'};

      expect(_parse(tx), isNull);
    });

    test('a transaction with no events', () {
      final tx = _recorded()..['events'] = <String, Object?>{};

      expect(_parse(tx), isNull);
    });

    test('malformed events are skipped, never thrown', () {
      final tx = _recorded();
      (tx['events']! as Map<String, Object?>)['contractEventsJson'] = [
        [
          'not an event',
          {'type': 'contract', 'contract_id': _usdcSac.value, 'body': 7},
          _event(_recorded()),
        ],
      ];

      expect(_parse(tx)?.hireId, HireId(8));
    });
  });

  group('first matching event wins', () {
    test('a later valid event does not replace the first', () {
      final tx = _recorded();
      final second = _copy(_event(tx));
      _entry(second, 'to_muxed_id')['val'] = {'u64': '9'};
      ((tx['events']! as Map)['contractEventsJson']! as List)
          .cast<List<Object?>>()
          .single
          .add(second);

      expect(_parse(tx)?.hireId, HireId(8));
    });

    test('the order decides, not the value', () {
      final tx = _recorded();
      final first = _copy(_event(tx));
      _entry(first, 'to_muxed_id')['val'] = {'u64': '9'};
      ((tx['events']! as Map)['contractEventsJson']! as List)
          .cast<List<Object?>>()
          .single
          .insert(0, first);

      expect(_parse(tx)?.hireId, HireId(9));
    });

    test('an invalid first event is skipped for a valid second', () {
      final tx = _recorded();
      final invalid = _copy(_event(tx));
      invalid['contract_id'] = StellarConfig.testnet.escrow.value;
      ((tx['events']! as Map)['contractEventsJson']! as List)
          .cast<List<Object?>>()
          .single
          .insert(0, invalid);

      expect(_parse(tx)?.hireId, HireId(8));
    });
  });
}
