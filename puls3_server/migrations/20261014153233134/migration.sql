BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "studio_draft" (
    "id" bigserial PRIMARY KEY,
    "owner" text NOT NULL,
    "revision" bigint NOT NULL,
    "manifestJson" text NOT NULL,
    "deployState" text NOT NULL,
    "liveVersion" bigint,
    "agentId" text,
    "retryFromStep" bigint,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "studio_draft_owner_idx" ON "studio_draft" USING btree ("owner");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261014153233134', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014153233134', "timestamp" = now();

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
