BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "chain_submission" (
    "id" bigserial PRIMARY KEY,
    "preparationId" text,
    "purpose" text NOT NULL,
    "transaction" text NOT NULL,
    "state" text NOT NULL,
    "errorCode" text,
    "explorerUrl" text,
    "updatedAt" timestamp without time zone NOT NULL,
    "hireId" bigint,
    "signedEnvelopeXdr" text,
    "validUntil" timestamp without time zone,
    "lastSentAt" timestamp without time zone,
    "sendAttempts" bigint DEFAULT 0,
    "createdAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "chain_submission_preparation_idx" ON "chain_submission" USING btree ("preparationId");
CREATE UNIQUE INDEX "chain_submission_transaction_idx" ON "chain_submission" USING btree ("transaction");
CREATE INDEX "chain_submission_state_idx" ON "chain_submission" USING btree ("state", "updatedAt");
CREATE INDEX "chain_submission_hire_idx" ON "chain_submission" USING btree ("hireId");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261005222242476', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261005222242476', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260129180959368', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129180959368', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260213194423028', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260213194423028', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260129181112269', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260129181112269', "timestamp" = now();


COMMIT;
