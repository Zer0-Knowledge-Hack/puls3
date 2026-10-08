BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "escrow_preparation" (
    "id" bigserial PRIMARY KEY,
    "preparationId" text NOT NULL,
    "hireId" bigint NOT NULL,
    "purpose" text NOT NULL,
    "signer" text NOT NULL,
    "unsignedEnvelopeXdr" text NOT NULL,
    "transactionHash" text NOT NULL,
    "sequence" bigint NOT NULL,
    "validUntil" timestamp without time zone NOT NULL,
    "jobExpiredAt" bigint,
    "rejectReason" text,
    "createdAt" timestamp without time zone NOT NULL,
    "supersededAt" timestamp without time zone,
    "submittedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "escrow_preparation_id_idx" ON "escrow_preparation" USING btree ("preparationId");
CREATE INDEX "escrow_preparation_hire_idx" ON "escrow_preparation" USING btree ("hireId");
CREATE INDEX "escrow_preparation_transaction_idx" ON "escrow_preparation" USING btree ("transactionHash");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "hire" ADD COLUMN "requestId" text;
ALTER TABLE "hire" ADD COLUMN "input" text;
ALTER TABLE "hire" ADD COLUMN "jobId" bigint;
CREATE UNIQUE INDEX "hire_consumer_request_idx" ON "hire" USING btree ("consumer", "requestId");
CREATE UNIQUE INDEX "hire_job_id_idx" ON "hire" USING btree ("jobId");

--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261008012344930', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261008012344930', "timestamp" = now();

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
