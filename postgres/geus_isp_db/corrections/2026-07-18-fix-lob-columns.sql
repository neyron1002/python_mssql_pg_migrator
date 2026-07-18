-- ============================================================================
-- Correccion DDL - columnas LOB/JSON que desbordaban en la migracion real
-- Geus_ISP_DB (MS SQL Server -> PostgreSQL)
-- Fecha: 2026-07-18
--
-- Contexto: el DDL declaraba columnas de texto mas cortas que el dato real del
-- origen. En la carga (migrate.py --data, COPY via psycopg) esto aborta con
--   "value too long for type character varying(N)".
-- Reproducido y verificado en este entorno (PostgreSQL 17.5 / MSSQL 2022).
--
-- Fuente de verdad: 01_schema.sql se genera desde el modelo EF (IspDbContext).
-- La correccion definitiva es quitar/ampliar el .HasMaxLength(...) de estas
-- propiedades y regenerar el DDL. Este ALTER es el equivalente para una base
-- ya creada. En 01_schema.sql de este repo estas columnas YA quedaron en `text`.
--
-- Aplicar:
--   psql "host=... dbname=Geus_ISP_DB user=postgres" -f 2026-07-18-fix-lob-columns.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- REQUERIDAS  (desbordaban -> bloqueaban la carga)
--   ContractConnection.JsonParameters : varchar(1000) < 2764 real
--   Report.Query                      : varchar(6000) < 7240 real
--   Report.JsonParameters             : varchar(6000) (3054 real; a text por consistencia)
-- ---------------------------------------------------------------------------
ALTER TABLE "ContractConnection" ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "Report"             ALTER COLUMN "Query"          TYPE text;
ALTER TABLE "Report"             ALTER COLUMN "JsonParameters" TYPE text;

-- ---------------------------------------------------------------------------
-- RECOMENDADAS  (hoy caben, pero guardan JSON sin cota natural: riesgo latente).
-- El DDL era inconsistente: JsonParameters era `text` en unas tablas y
-- varchar(1000|6000) en otras. Se unifican todas a `text`.
-- (En 01_schema.sql de este repo ya estan aplicadas; se dejan aqui para
--  cualquier base creada con el DDL anterior.)
-- ---------------------------------------------------------------------------
ALTER TABLE "DocumentTemplate"          ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "Company"                   ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "PlanService"               ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "Zone"                      ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "GenericService"            ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "Neighborhood"              ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "Contract"                  ALTER COLUMN "JsonParameters" TYPE text;
ALTER TABLE "ContractConnectionHistory" ALTER COLUMN "JsonParameters" TYPE text;
