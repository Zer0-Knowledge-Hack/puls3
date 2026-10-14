BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "studio_deploy" (
    "id" bigserial PRIMARY KEY,
    "draftId" bigint NOT NULL,
    "owner" text NOT NULL,
    "state" text NOT NULL,
    "agentWallet" text NOT NULL,
    "registrationUri" text NOT NULL,
    "preparationId" text,
    "unsignedEnvelopeXdr" text,
    "authorizationEntryXdr" text,
    "signatureExpirationLedger" bigint,
    "registrationHash" text,
    "walletTxHash" text,
    "registryAgentId" bigint,
    "expiresAt" timestamp without time zone,
    "failureCode" text,
    "retryFromStep" bigint,
    "walletAuthJson" text,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "studio_deploy_draft_idx" ON "studio_deploy" USING btree ("draftId");


--
-- MIGRATION VERSION FOR puls3
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('puls3', '20261014182841548', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014182841548', "timestamp" = now();

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
