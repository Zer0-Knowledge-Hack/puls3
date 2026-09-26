import 'package:puls3_domain/puls3_domain.dart';
import 'package:test/test.dart';

// Real testnet addresses: an account and the Identity Registry contract.
const account = 'GBY33NK3HMKQUKHL7YSCJ2W5JMJ62MEVKEJTRUWNQXBQIFLUVZY6TJ4R';
const contract = 'CD5QZOKGRBV35C5SDT6PG7S72XGG4BHQAC2L56YLNBJDUL4LDMTXFIJJ';

Matcher addressError(StellarAddressProblem problem) => throwsA(
  isA<InvalidStellarAddress>().having((e) => e.problem, 'problem', problem),
);

void main() {
  group('I1 StellarAddress', () {
    test('accepts a valid account address', () {
      final address = StellarAddress.parse(account);
      expect(address.value, account);
      expect(address.kind, StellarAddressKind.account);
    });

    test('accepts a valid contract address', () {
      final address = StellarAddress.parse(contract);
      expect(address.kind, StellarAddressKind.contract);
    });

    test('is equal by value', () {
      expect(StellarAddress.parse(account), StellarAddress.parse(account));
      expect(
        StellarAddress.parse(account).hashCode,
        StellarAddress.parse(account).hashCode,
      );
    });

    test('rejects the wrong length', () {
      expect(
        () => StellarAddress.parse(account.substring(0, 55)),
        addressError(StellarAddressProblem.wrongLength),
      );
      expect(
        () => StellarAddress.parse('${account}A'),
        addressError(StellarAddressProblem.wrongLength),
      );
    });

    test('rejects characters outside base32', () {
      expect(
        () => StellarAddress.parse(account.toLowerCase()),
        addressError(StellarAddressProblem.invalidCharacters),
      );
      expect(
        () => StellarAddress.parse('${account.substring(0, 55)}1'),
        addressError(StellarAddressProblem.invalidCharacters),
      );
    });

    test('rejects a prefix other than G or C', () {
      expect(
        () => StellarAddress.parse('A${account.substring(1)}'),
        addressError(StellarAddressProblem.wrongPrefix),
      );
      expect(
        () => StellarAddress.parse('M${account.substring(1)}'),
        addressError(StellarAddressProblem.wrongPrefix),
      );
    });

    test('rejects a bad checksum', () {
      final last = account[account.length - 1];
      final tampered = account.substring(0, 55) + (last == 'A' ? 'B' : 'A');
      expect(
        () => StellarAddress.parse(tampered),
        addressError(StellarAddressProblem.badChecksum),
      );
    });

    test('rejects a changed payload even when the last character is valid', () {
      final tampered = '${account.substring(0, 10)}A${account.substring(11)}';
      expect(tampered, isNot(account));
      expect(
        () => StellarAddress.parse(tampered),
        addressError(StellarAddressProblem.badChecksum),
      );
    });
  });

  group('I2 UsdcAmount', () {
    test('stores whole stroops', () {
      expect(UsdcAmount.stroops(5000000).stroops, 5000000);
      expect(UsdcAmount.zero.stroops, 0);
      expect(UsdcAmount.stroopsPerUsdc, 10000000);
    });

    test('is equal by value', () {
      expect(UsdcAmount.stroops(3), UsdcAmount.stroops(3));
    });

    test('rejects a negative amount', () {
      expect(() => UsdcAmount.stroops(-1), throwsA(isA<InvalidAmount>()));
    });

    test('rejects amounts above 2^53 - 1', () {
      expect(
        UsdcAmount.stroops(UsdcAmount.maxStroops).stroops,
        9007199254740991,
      );
      expect(
        () => UsdcAmount.stroops(UsdcAmount.maxStroops + 1),
        throwsA(isA<InvalidAmount>()),
      );
    });

    test('knows whether it is positive', () {
      expect(UsdcAmount.stroops(1).isPositive, isTrue);
      expect(UsdcAmount.zero.isPositive, isFalse);
    });
  });

  group('I3 AgentId', () {
    test('accepts the u32 range', () {
      expect(AgentId(0).value, 0);
      expect(AgentId(4294967295).value, 4294967295);
    });

    test('rejects values outside u32', () {
      expect(() => AgentId(-1), throwsA(isA<InvalidAgentId>()));
      expect(() => AgentId(4294967296), throwsA(isA<InvalidAgentId>()));
    });
  });

  group('I4 HireId', () {
    test('accepts 1 to 2^53 - 1', () {
      expect(HireId(1).value, 1);
      expect(HireId(9007199254740991).value, 9007199254740991);
    });

    test('rejects zero, negatives and values above 2^53 - 1', () {
      expect(() => HireId(0), throwsA(isA<InvalidHireId>()));
      expect(() => HireId(-5), throwsA(isA<InvalidHireId>()));
      expect(() => HireId(9007199254740992), throwsA(isA<InvalidHireId>()));
    });
  });

  group('I5 TransactionHash', () {
    const hash =
        '17ac14e085609df8e042b84e6c25aac7e1c30344eaa1b1fd0bcbed399b65243f';

    test('accepts 64 lowercase hex characters', () {
      expect(TransactionHash.parse(hash).value, hash);
    });

    test('rejects the wrong length, uppercase and non-hex', () {
      expect(
        () => TransactionHash.parse(hash.substring(1)),
        throwsA(isA<InvalidTransactionHash>()),
      );
      expect(
        () => TransactionHash.parse(hash.toUpperCase()),
        throwsA(isA<InvalidTransactionHash>()),
      );
      expect(
        () => TransactionHash.parse('${hash.substring(1)}g'),
        throwsA(isA<InvalidTransactionHash>()),
      );
    });
  });
}
