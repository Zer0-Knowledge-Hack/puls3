@Tags(['integration'])
library;

import 'package:puls3_server/src/auth/wallet_idp.dart';
import 'package:puls3_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:stellar_dart/stellar_dart.dart' as stellar;
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  final walletA = _address(9);
  final walletB = _address(3);

  withServerpod('Given WalletIdp', (sessionBuilder, _) {
    WalletIdp idp() => WalletIdp(
      tokenManager: JwtConfigFromPasswords().build(
        authUsers: const AuthUsers(),
      ),
    );

    test(
      'the first sign-in creates one auth user and one wallet row',
      () async {
        final session = sessionBuilder.build();

        final success = await idp().signIn(session, wallet: walletA);

        final rows = await WalletAccount.db.find(
          session,
          where: (t) => t.wallet.equals(walletA),
        );
        expect(rows, hasLength(1));
        expect(rows.single.authUserId, success.authUserId);
        expect(
          await AuthUser.db.count(
            session,
            where: (t) => t.id.equals(success.authUserId),
          ),
          1,
        );
        expect(success.token, isNotEmpty);
        expect(success.refreshToken, isNotEmpty);
        expect(
          success.tokenExpiresAt!.difference(DateTime.now().toUtc()),
          greaterThan(const Duration(minutes: 9)),
        );
      },
    );

    test(
      'a second sign-in reuses the user and issues a new token pair',
      () async {
        final session = sessionBuilder.build();
        final first = await idp().signIn(session, wallet: walletA);

        final second = await idp().signIn(session, wallet: walletA);

        expect(second.authUserId, first.authUserId);
        expect(second.token, isNot(first.token));
        expect(second.refreshToken, isNot(first.refreshToken));
        expect(
          await WalletAccount.db.count(
            session,
            where: (t) => t.wallet.equals(walletA),
          ),
          1,
        );
        expect(await AuthUser.db.count(session), 1);
      },
    );

    test('two wallets get two users and a token stays on its wallet', () async {
      final session = sessionBuilder.build();
      final tokens = JwtConfigFromPasswords().build(
        authUsers: const AuthUsers(),
      );
      final provider = WalletIdp(tokenManager: tokens);
      final a = await provider.signIn(session, wallet: walletA);
      final b = await provider.signIn(session, wallet: walletB);

      expect(a.authUserId, isNot(b.authUserId));
      final info = await tokens.validateToken(session, a.token);
      expect(info!.userIdentifier, a.authUserId.toString());
      final row = await WalletAccount.db.findFirstRow(
        session,
        where: (t) => t.authUserId.equals(a.authUserId),
      );
      expect(row!.wallet, walletA);
    });
  });

  withServerpod(
    'Given committed wallet accounts',
    (sessionBuilder, _) {
      tearDown(() async {
        final session = sessionBuilder.build();
        final rows = await WalletAccount.db.find(
          session,
          where: (t) => t.wallet.equals(walletA) | t.wallet.equals(walletB),
        );
        for (final row in rows) {
          await AuthUser.db.deleteWhere(
            session,
            where: (t) => t.id.equals(row.authUserId),
          );
        }
      });

      test(
        'a second insert of the same wallet or auth user rolls back',
        () async {
          final session = sessionBuilder.build();
          final tokens = JwtConfigFromPasswords().build(
            authUsers: const AuthUsers(),
          );
          final first = await WalletIdp(tokenManager: tokens).signIn(
            session,
            wallet: walletA,
          );
          final users = await AuthUser.db.count(session);
          final accountRows = await WalletAccount.db.count(session);

          expect(
            () => session.db.transaction((transaction) async {
              final extra = await const AuthUsers().create(
                session,
                transaction: transaction,
              );
              await WalletAccount.db.insertRow(
                session,
                WalletAccount(
                  wallet: walletA,
                  authUserId: extra.id,
                  createdAt: DateTime.now().toUtc(),
                ),
                transaction: transaction,
              );
            }),
            throwsA(_uniqueViolation),
          );
          expect(
            () => session.db.transaction(
              (transaction) => WalletAccount.db.insertRow(
                session,
                WalletAccount(
                  wallet: walletB,
                  authUserId: first.authUserId,
                  createdAt: DateTime.now().toUtc(),
                ),
                transaction: transaction,
              ),
            ),
            throwsA(_uniqueViolation),
          );

          expect(await AuthUser.db.count(session), users);
          expect(await WalletAccount.db.count(session), accountRows);
        },
      );

      test('the advisory lock leaves one user', () async {
        final tokens = JwtConfigFromPasswords().build(
          authUsers: const AuthUsers(),
        );
        final provider = WalletIdp(tokenManager: tokens);

        final results = await Future.wait([
          provider.signIn(sessionBuilder.build(), wallet: walletA),
          provider.signIn(sessionBuilder.build(), wallet: walletA),
        ]);

        expect(results[0].authUserId, results[1].authUserId);
        expect(results[0].token, isNot(results[1].token));
        final session = sessionBuilder.build();
        expect(
          await WalletAccount.db.count(
            session,
            where: (t) => t.wallet.equals(walletA),
          ),
          1,
        );
        expect(
          await AuthUser.db.count(
            session,
            where: (t) => t.id.equals(results[0].authUserId),
          ),
          1,
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
  );
}

String _address(int seed) => stellar.StellarPrivateKey.fromBytes(
  List<int>.filled(32, seed),
).toPublicKey().toAddress().address;

final _uniqueViolation = isA<DatabaseQueryException>().having(
  (error) => error.code,
  'code',
  '23505',
);
