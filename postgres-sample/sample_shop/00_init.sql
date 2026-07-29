-- ============================================================================
-- 00_init.sql  -  Inicializacion previa del esquema destino (SAMPLE)
-- Base de ejemplo: sample_shop  (una tiendita: categorias, productos, clientes,
-- pedidos, lineas de pedido y tokens de API)
--
-- Este archivo demuestra el PRIMER paso del contrato DDL_DIR: extensiones,
-- colaciones y tipos que deben existir ANTES de crear las tablas.
--
-- migrate.py --schema --fresh dropea y recrea la base, por eso aqui se usa
-- CREATE ... a secas (sin IF NOT EXISTS): la base siempre arranca limpia.
-- ============================================================================

-- Para PK uuid con valor por defecto en inserts nuevos de la app.
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- provee gen_random_uuid()

-- Colacion case-insensitive / accent-sensitive: analogo del *_CI_AS de MSSQL.
-- Requiere PostgreSQL con ICU (ver README). Se aplica a Email/login en 02.
CREATE COLLATION "sample_ci_as" (
    provider      = icu,
    locale        = 'und-u-ks-level2',
    deterministic = false
);
