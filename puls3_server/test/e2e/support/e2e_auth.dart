// Real wallet sign-in for the E2E suites: the consumer signs a SEP-10
// challenge through `WalletAuthEndpoint`, and the resulting JWT drives the
// hire endpoints exactly as a browser session would.
import 'dart:convert';
import 'dart:typed_data';

import 'package:puls3_server/src/auth/wallet_auth_config.dart';
import 'package:puls3_server/src/auth/wallet_auth_endpoint.dart';
import 'package:puls3_server/src/ledger/network_id.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import '../../integration/test_tools/serverpod_test_tools.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;

import 'e2e_sandbox.dart';

/// Points `WalletAuthEndpoint` at the sandbox: a throwaway server signing
/// key and the real account lookup on the local network.
TokenManager useSandboxAuth(E2eSandbox sandbox, E2eAccount serverAccount) {
  final tokens = JwtConfigFromPasswords().build(authUsers: const AuthUsers());
  AuthServices.set(tokenManagerBuilders: [JwtConfigFromPasswords()]);
  WalletAuthEndpoint.debugConfig = WalletAuthConfig(
    signingKey: serverAccount.key.toBase32(),
    serverAccount: serverAccount.address.value,
    homeDomain: 'e2e.puls3.local',
    webAuthDomain: 'e2e.puls3.local',
    networkPassphrase: sandbox.passphrase,
  );
  WalletAuthEndpoint.debugChain = sandbox.wiring.accounts;
  WalletAuthEndpoint.debugTokens = tokens;
  return tokens;
}

/// A session builder authenticated as [account], through the real
/// challenge and verify calls.
Future<TestSessionBuilder> signIn(
  E2eSandbox sandbox,
  TestSessionBuilder sessionBuilder,
  TokenManager tokens,
  E2eAccount account,
) async {
  final session = sessionBuilder.build();
  final endpoint = WalletAuthEndpoint();
  final challenge = await endpoint.createChallenge(
    session,
    account.address.value,
  );
  final success = await endpoint.verifyChallenge(
    session,
    challenge.challengeId,
    account.address.value,
    _signChallenge(challenge.payload, account.key, sandbox.passphrase),
  );
  final info = await tokens.validateToken(session, success.token);
  return sessionBuilder.copyWith(
    authentication: AuthenticationOverride.authenticationInfo(
      info!.userIdentifier,
      info.scopes,
      authId: info.authId,
    ),
  );
}

String _signChallenge(
  String xdr,
  stellar.StellarPrivateKey client,
  String passphrase,
) {
  final decoded =
      stellar.Envelope.fromXdr(base64Decode(xdr))
          as stellar.TransactionV1Envelope;
  final hash = Uint8List.fromList(
    stellar.TransactionSignaturePayload(
      networkId: networkIdOf(passphrase),
      taggedTransaction: decoded.tx,
    ).txHash(),
  );
  return base64Encode(
    stellar.TransactionV1Envelope(
      tx: decoded.tx,
      signatures: [decoded.signatures.single, client.sign(hash)],
    ).toVariantXDR(),
  );
}
