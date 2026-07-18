-- =====================================================================
-- Geus_ISP_DB  ·  02_constraints_indexes.sql  ·  Collations & extra indexes
-- =====================================================================
-- Runs after 01_schema.sql. Applies the case-insensitive collation from
-- 00_init.sql to the columns whose lookups are EQUALITY-based, so that a
-- login / email match is case-insensitive (an MSSQL CI_AS behaviour that
-- would otherwise fail SILENTLY under PostgreSQL's default deterministic
-- collation).
-- =====================================================================

-- Login / contact email is matched by equality (email.Email == filter.Email
-- in EmailRepository). Case-insensitive equality here prevents silent login
-- and contact-lookup failures. The UNIQUE index on (IdPerson, Email) is
-- rebuilt automatically and becomes case-insensitive as well.
ALTER TABLE "PersonEmail"
    ALTER COLUMN "Email" TYPE character varying(100) COLLATE "spanish_ci_as";

-- ---------------------------------------------------------------------
-- NOTE (needs-human / query-layer follow-up):
-- PlanService search (PlanServiceRepository.PaginatePlanServiceAsync) uses
-- EF.Functions.Like on "PlanService"/"Description". PostgreSQL does NOT
-- support LIKE/pattern matching on a NON-deterministic collation, so those
-- columns are intentionally left on the default (deterministic) collation.
-- Case-insensitive substring search must be done at the query layer with
-- ILIKE or lower(col) LIKE lower(:pattern) — a code change outside the DDL.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- Optional performance indexes: the tested corpus ships additional
-- covering / lookup indexes in
--   ia-assets/pg-migration/25.08.27_Geus_ISP_DB_Index_PG.psql
--   ia-assets/pg-migration/25.08.27_Geus_ISP_DB_missing_index_PG.psql
-- The functional indexes EF relies on are already emitted in 01_schema.sql;
-- the corpus perf indexes can be folded in here once validated against the
-- generated column names. Not required for correctness or the test suite.
-- ---------------------------------------------------------------------
