import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_domain/puls3_domain.dart';

import 'strkey.dart';
import 'xdr_invoke_encoder.dart' show XdrWriter;

/// A classic Stellar credit asset, `CODE:ISSUER` (for example the asset behind
/// the USDC Stellar Asset Contract). An account must hold a trustline to it
/// before the SAC can credit that account.
final class ClassicAsset {
  const ClassicAsset._(this.code, this.issuer);

  /// Parses `CODE:ISSUER`. The code is 1 to 12 ASCII letters or digits and the
  /// issuer a `G...` account. Anything else throws a [FormatException].
  factory ClassicAsset.parse(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2 ||
        !RegExp(r'^[A-Za-z0-9]{1,12}$').hasMatch(parts[0])) {
      throw FormatException('not a CODE:ISSUER classic asset', value);
    }
    final issuer = StellarAddress.parse(parts[1]);
    if (!issuer.value.startsWith('G')) {
      throw FormatException('the issuer must be a G... account', value);
    }
    return ClassicAsset._(parts[0], issuer.value);
  }

  /// Circle's testnet USDC, the asset of the testnet USDC SAC
  /// `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA`.
  static const circleTestnetUsdc = ClassicAsset._(
    'USDC',
    'GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5',
  );

  final String code;

  /// The issuer's `G...` address.
  final String issuer;

  /// The asset as XDR `ChangeTrustAsset` / `TrustLineAsset` (both encode a
  /// credit asset the same way): type, the code padded with zeros to 4 or 12
  /// bytes, then the issuer `AccountID`.
  Uint8List toXdr() {
    final long = code.length > 4;
    final padded = Uint8List(long ? 12 : 4)..setAll(0, ascii.encode(code));
    final out = XdrWriter()
      ..uint32(long ? _assetTypeAlphanum12 : _assetTypeAlphanum4)
      ..opaque(padded)
      ..uint32(_publicKeyTypeEd25519)
      ..opaque(rawKey(StellarAddress.parse(issuer)));
    return out.bytes;
  }

  @override
  bool operator ==(Object other) =>
      other is ClassicAsset && other.code == code && other.issuer == issuer;

  @override
  int get hashCode => Object.hash(code, issuer);

  @override
  String toString() => '$code:$issuer';
}

// AssetType and PublicKeyType discriminants, from Stellar-ledger-entries.x.
const _assetTypeAlphanum4 = 1;
const _assetTypeAlphanum12 = 2;
const _publicKeyTypeEd25519 = 0;
