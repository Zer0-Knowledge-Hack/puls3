BEGIN;

--
-- ACTION ALTER TABLE
--
DROP INDEX "chain_submission_state_idx";
ALTER TABLE "chain_submission" ADD COLUMN "lastCheckedAt" timestamp without time zone;
-- Rows from before this column count as checked when they were created.
UPDATE "chain_submission" SET "lastCheckedAt" = "createdAt" WHERE "lastCheckedAt" IS NULL;
CREATE INDEX "chain_submission_state_idx" ON "chain_submission" USING btree ("state", "lastCheckedAt", "id");

--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261005231322835', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261005231322835', "timestamp" = now();

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
