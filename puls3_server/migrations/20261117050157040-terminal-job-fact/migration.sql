BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "terminal_job_fact" (
    "id" bigserial PRIMARY KEY,
    "escrow" text NOT NULL,
    "jobId" bigint NOT NULL,
    "client" text NOT NULL,
    "agentId" bigint NOT NULL,
    "state" text NOT NULL,
    "observedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "terminal_job_fact_job_idx" ON "terminal_job_fact" USING btree ("escrow", "jobId");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261117050157040-terminal-job-fact', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261117050157040-terminal-job-fact', "timestamp" = now();

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
