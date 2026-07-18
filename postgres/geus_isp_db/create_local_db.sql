-- =====================================================================
-- Geus_ISP_DB  ·  create_local_db.sql  ·  Manual bootstrap (local/test)
-- =====================================================================
-- Target engine : PostgreSQL 18 (ICU locale provider)
--
-- One-shot script to create the database FROM SCRATCH and apply the full
-- committed DDL (00..03) for a LOCAL / TEST environment. This is the manual
-- equivalent of what the integration fixture does automatically
-- (ISP.Api.IntegrationTests/Fixtures/PostgresIspDbFixture.cs): the fixture
-- lets Testcontainers create the database via POSTGRES_DB + ICU init args;
-- here we create it ourselves so you can run everything by hand with psql.
--
-- USO / HOW TO RUN
-- ----------------
-- Debe ejecutarse conectado a una BD de mantenimiento (p. ej. "postgres"),
-- NO a "Geus_ISP_DB", porque hace DROP/CREATE de esa base:
--
--     psql -v ON_ERROR_STOP=1 -U postgres -h localhost -d postgres \
--          -f database/postgres/geus_isp_db/create_local_db.sql
--
-- El cluster debería estar inicializado con proveedor de locale ICU es-ES
-- (initdb --locale-provider=icu --icu-locale=es-ES). Si no lo está, la BD
-- se crea igual desde template0 con ICU es-ES; solo el lado libc (LC_*) se
-- hereda de template0. Para un entorno de pruebas turnkey usa el wrapper
-- create_local_db.sh, que levanta postgres:18 ya inicializado con ICU es-ES.
--
-- Re-ejecutable: hace DROP ... WITH (FORCE) para dejar la BD limpia cada vez.
-- =====================================================================

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------
-- 1) Crear la base de datos (locale ICU es-ES, análogo a MSSQL *_CI_AS a
--    nivel de columna, que se afina en 00_init.sql / 02_*.sql).
--    WITH (FORCE) termina conexiones abiertas para poder recrearla.
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS "Geus_ISP_DB" WITH (FORCE);

CREATE DATABASE "Geus_ISP_DB"
    WITH ENCODING        = 'UTF8'
         LOCALE_PROVIDER = 'icu'
         ICU_LOCALE      = 'es-ES'
         TEMPLATE        = template0;

-- ---------------------------------------------------------------------
-- 2) Reconectar a la base recién creada y aplicar el DDL en orden.
--    \ir = include relativo AL DIRECTORIO DE ESTE SCRIPT, por lo que los
--    includes resuelven aunque psql se invoque desde otro CWD.
--    ON_ERROR_STOP persiste tras el \c dentro de la misma sesión.
-- ---------------------------------------------------------------------
\connect "Geus_ISP_DB"

\echo '>> 00_init.sql (pgcrypto + colación spanish_ci_as)'
\ir 00_init.sql

\echo '>> 01_schema.sql (57 tablas: PK/FK/índices/defaults)'
\ir 01_schema.sql

\echo '>> 02_constraints_indexes.sql (colación CI en PersonEmail.Email)'
\ir 02_constraints_indexes.sql

\echo '>> 03_views.sql (24 vistas)'
\ir 03_views.sql

\echo ''
\echo '== Geus_ISP_DB creada y DDL aplicado (00..03). =='
