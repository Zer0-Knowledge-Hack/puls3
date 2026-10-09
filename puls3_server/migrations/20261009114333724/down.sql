BEGIN;

DROP TABLE IF EXISTS "wallet_account";
DROP TABLE IF EXISTS "wallet_challenge";

UPDATE "serverpod_migrations"
    SET "version" = '20261008045629402', "timestamp" = now()
    WHERE "module" = 'puls3' AND "version" = '20261009114333724';

COMMIT;
