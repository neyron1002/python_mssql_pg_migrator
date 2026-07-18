-- =====================================================================
-- Geus_ISP_DB  ·  00_init.sql  ·  Database / extensions / collations
-- =====================================================================
-- Target engine : PostgreSQL 18 (ICU locale provider)
--
-- The database itself is created by the deployment tooling. For the
-- integration suite, Testcontainers creates it via POSTGRES_DB with:
--     POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=es-ES"
-- so the cluster/default collation is ICU es-ES (accent- and
-- case-sensitive). To create it manually on a server, use:
--
--   CREATE DATABASE "Geus_ISP_DB"
--       WITH ENCODING = 'UTF8'
--            LOCALE_PROVIDER = 'icu'
--            ICU_LOCALE = 'es-ES'
--            TEMPLATE = template0;
--
-- Everything below runs *inside* the Geus_ISP_DB database.
-- =====================================================================

-- gen_random_uuid(): built into PostgreSQL 13+ core; the extension is a
-- harmless no-op there and keeps the script portable to older servers.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------
-- Case-insensitive, accent-sensitive collation (MSSQL *_CI_AS analogue).
-- Applied in 02_constraints_indexes.sql to login / email / search
-- columns so that equality and uniqueness are case-insensitive, avoiding
-- SILENT login/lookup failures after the SQL Server -> PostgreSQL move.
--
-- ICU strength ks-level2 = primary(base letters) + secondary(accents):
--   case-INsensitive, accent-SENSITIVE  ==  SQL Server CI_AS.
-- deterministic=false is required for a case-insensitive '=' operator.
-- ---------------------------------------------------------------------
DROP COLLATION IF EXISTS "spanish_ci_as";
CREATE COLLATION "spanish_ci_as" (
    provider      = icu,
    locale        = 'es-ES-u-ks-level2',
    deterministic = false
);
