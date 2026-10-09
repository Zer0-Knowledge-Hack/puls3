BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "wallet_account" (
    "id" bigserial PRIMARY KEY,
    "wallet" text NOT NULL,
    "authUserId" uuid NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "wallet_account_wallet_idx" ON "wallet_account" USING btree ("wallet");
CREATE UNIQUE INDEX "wallet_account_auth_user_idx" ON "wallet_account" USING btree ("authUserId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "wallet_challenge" (
    "id" bigserial PRIMARY KEY,
    "challengeId" text NOT NULL,
    "wallet" text NOT NULL,
    "challengeXdr" text NOT NULL,
    "transactionHash" text NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "consumedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "wallet_challenge_id_idx" ON "wallet_challenge" USING btree ("challengeId");
CREATE INDEX "wallet_challenge_wallet_idx" ON "wallet_challenge" USING btree ("wallet");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "wallet_account"
    ADD CONSTRAINT "wallet_account_fk_0"
    FOREIGN KEY("authUserId")
    REFERENCES "serverpod_auth_core_user"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261009114333724', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261009114333724', "timestamp" = now();

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
