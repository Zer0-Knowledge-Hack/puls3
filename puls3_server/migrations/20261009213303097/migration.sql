BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "agent_record" (
    "id" bigserial PRIMARY KEY,
    "registryId" bigint NOT NULL,
    "agentId" text NOT NULL,
    "name" text NOT NULL,
    "description" text NOT NULL,
    "skills" json NOT NULL,
    "priceUsdcStroops" bigint NOT NULL,
    "wallet" text,
    "model" text
);

-- Indexes
CREATE UNIQUE INDEX "agent_record_registry_idx" ON "agent_record" USING btree ("registryId");
CREATE INDEX "agent_record_agent_id_idx" ON "agent_record" USING btree ("agentId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "catalog_index_state" (
    "id" bigserial PRIMARY KEY,
    "network" text NOT NULL,
    "lastProcessedLedger" bigint NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "catalog_index_network_idx" ON "catalog_index_state" USING btree ("network");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261009213303097', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261009213303097', "timestamp" = now();

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
