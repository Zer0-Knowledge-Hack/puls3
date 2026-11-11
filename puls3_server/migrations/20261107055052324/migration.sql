BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "builder_credential" (
    "id" bigserial PRIMARY KEY,
    "owner" text NOT NULL,
    "provider" text NOT NULL,
    "accountId" text,
    "ciphertext" text NOT NULL,
    "nonce" text NOT NULL,
    "mac" text NOT NULL,
    "keyVersion" bigint NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "builder_credential_owner_provider_idx" ON "builder_credential" USING btree ("owner", "provider");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261107055052324', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261107055052324', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
