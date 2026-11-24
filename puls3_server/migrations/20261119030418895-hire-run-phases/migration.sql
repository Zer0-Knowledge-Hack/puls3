BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "hire_run" ADD COLUMN "loopState" text;
ALTER TABLE "hire_run" ADD COLUMN "pendingToolCallId" text;
ALTER TABLE "hire_run" ADD COLUMN "childHireId" bigint;
ALTER TABLE "hire_run" ADD COLUMN "childRequest" text;

--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261119030418895-hire-run-phases', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261119030418895-hire-run-phases', "timestamp" = now();

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
