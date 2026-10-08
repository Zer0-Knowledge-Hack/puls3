# Work with Serverpod 4

The repository is pinned to Flutter 3.44.4, Dart 3.12.2, Serverpod packages
4.0.4, and `serverpod_cli` 4.0.4. Upgrade those versions together so generated
server, client, and test code stays reproducible across the team and CI.

## Update your workstation

```bash
cd <your-flutter-folder>
git fetch --tags
git checkout 3.44.4
flutter --version

dart pub global activate serverpod_cli 4.0.4
serverpod version

cd <puls3-repository>
dart pub get
cd puls3_server
serverpod generate
git diff --exit-code -- ../puls3_server ../puls3_client
```

The two version commands must report Dart 3.12.2 and Serverpod 4.0.4. A clean
final diff proves that the checked-in generated code matches your CLI.

## Apply the database migration

Serverpod 4 adds and updates internal tables. Back up persistent data, then run
the server once with migrations enabled:

```bash
cd puls3_server
dart run bin/main.dart --apply-migrations
```

The migration recreates only
`serverpod_auth_idp_rate_limited_request_attempt` to rename its `nonce` column
to `key`. Existing rows are copied into the new table within the same
transaction, so rate-limit history is preserved. Accounts, sessions, and other
authentication data are not touched. Do not run
this against production until its backup and restore path have been tested.

## Roll back

Code rollback and database rollback are separate:

1. Stop every Serverpod 4 server instance.
2. Restore the pre-upgrade database backup. Do not run Serverpod 3 against a
   database after the Serverpod 4 migration.
3. Revert the Serverpod 4 upgrade commit(s).
4. Restore Flutter 3.41.4 / Dart 3.11.1 and `serverpod_cli` 3.4.13.
5. Run `dart pub get`, regenerate, and verify that generation is clean before
   restarting the old server.

Serverpod migrations are forward-only artifacts; deleting the new migration
directory does not undo SQL already applied to a database.
