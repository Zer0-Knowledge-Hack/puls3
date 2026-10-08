BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "agent_wallet" (
    "id" bigserial PRIMARY KEY,
    "owner" text NOT NULL,
    "address" text NOT NULL,
    "ciphertext" text NOT NULL,
    "nonce" text NOT NULL,
    "mac" text NOT NULL,
    "keyVersion" bigint NOT NULL,
    "agentId" bigint,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "agent_wallet_address_idx" ON "agent_wallet" USING btree ("address");
CREATE INDEX "agent_wallet_owner_idx" ON "agent_wallet" USING btree ("owner");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261008054958966', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261008054958966', "timestamp" = now();

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
