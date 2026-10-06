BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "hire" (
    "id" bigserial PRIMARY KEY,
    "consumer" text NOT NULL,
    "agentId" bigint NOT NULL,
    "price" bigint NOT NULL,
    "manifestVersion" bigint NOT NULL,
    "expiredAt" bigint NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "hire_payment" (
    "id" bigserial PRIMARY KEY,
    "hireId" bigint NOT NULL,
    "transactionHash" text NOT NULL,
    "jobId" bigint NOT NULL,
    "payer" text NOT NULL,
    "payee" text NOT NULL,
    "amount" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "hire_id" ON "hire_payment" USING btree ("hireId");
CREATE UNIQUE INDEX "transaction_hash" ON "hire_payment" USING btree ("transactionHash");
CREATE UNIQUE INDEX "job_id" ON "hire_payment" USING btree ("jobId");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261006210458593', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261006210458593', "timestamp" = now();

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
