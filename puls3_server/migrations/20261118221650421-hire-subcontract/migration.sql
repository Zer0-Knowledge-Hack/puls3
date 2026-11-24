BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "hire" ADD COLUMN "subcontractReserve" bigint NOT NULL DEFAULT 0;
ALTER TABLE "hire" ADD COLUMN "allowRelatedParty" boolean NOT NULL DEFAULT true;
ALTER TABLE "hire" ADD COLUMN "parentHireId" bigint;
CREATE INDEX "hire_parent_idx" ON "hire" USING btree ("parentHireId");
--
-- ACTION CREATE TABLE
--
CREATE TABLE "hire_receipt_line" (
    "id" bigserial PRIMARY KEY,
    "parentHireId" bigint NOT NULL,
    "childHireId" bigint,
    "childJobId" bigint,
    "providerAgentId" bigint NOT NULL,
    "providerWallet" text NOT NULL,
    "budget" bigint NOT NULL,
    "fee" bigint,
    "payout" bigint,
    "state" text NOT NULL,
    "deliverableHash" text,
    "createTransaction" text,
    "settleTransaction" text,
    "relatedParty" boolean NOT NULL,
    "justification" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "hire_receipt_line_parent_idx" ON "hire_receipt_line" USING btree ("parentHireId");
CREATE UNIQUE INDEX "hire_receipt_line_child_job_idx" ON "hire_receipt_line" USING btree ("childJobId");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261118221650421-hire-subcontract', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261118221650421-hire-subcontract', "timestamp" = now();

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
