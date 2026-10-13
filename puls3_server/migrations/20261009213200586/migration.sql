BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "hire_run" (
    "id" bigserial PRIMARY KEY,
    "hireId" bigint NOT NULL,
    "state" text NOT NULL,
    "queuedAt" timestamp without time zone NOT NULL,
    "startedAt" timestamp without time zone,
    "finishedAt" timestamp without time zone,
    "result" text,
    "failureReason" text,
    "attempts" bigint NOT NULL DEFAULT 0,
    "notBefore" timestamp without time zone,
    "lastError" text
);

-- Indexes
CREATE UNIQUE INDEX "hire_run_hire_idx" ON "hire_run" USING btree ("hireId");
CREATE INDEX "hire_run_state_idx" ON "hire_run" USING btree ("state");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261009213200586', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261009213200586', "timestamp" = now();

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
