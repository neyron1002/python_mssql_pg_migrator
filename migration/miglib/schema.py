"""schema.py - Crea la base PostgreSQL y aplica el DDL 00..03, todo via psycopg.

Reemplaza el `psql -f` del orquestador shell: psycopg ejecuta el contenido de
cada archivo .sql. psycopg (v3) admite VARIOS statements en un solo execute()
cuando NO se pasan parametros -- que es justo el caso de los DDL 00..03 (no usan
placeholders). No hay bloques dollar-quoted en esos archivos.

El DDL sigue siendo la fuente de verdad del esquema
(database/postgres/geus_isp_db/00..03); aqui solo se aplica.

(Archivo en ASCII puro a proposito.)
"""
from __future__ import annotations

import os

from . import config

DDL_FILES = ("00_init", "01_schema", "02_constraints_indexes", "03_views")


def ddl_dir():
    """Directorio del DDL. Override con DDL_DIR; default ../postgres/geus_isp_db."""
    override = os.environ.get("DDL_DIR")
    if override:
        return override
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # database/migration
    return os.path.normpath(os.path.join(here, "..", "postgres", "geus_isp_db"))


def _lit(s):
    return "'%s'" % s.replace("'", "''")


def _create_database(pg_db):
    """DROP + CREATE de la base destino con locale ICU (equivalente a --fresh)."""
    icu = os.environ.get("PG_ICU_LOCALE", "es-ES")
    admin_db = os.environ.get("PG_ADMIN_DB", "postgres")
    admin = config.connect_pg(dbname=admin_db)
    try:
        admin.execute(
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
            "WHERE datname=%s AND pid<>pg_backend_pid()", (pg_db,))
        admin.execute("DROP DATABASE IF EXISTS %s" % config.qi(pg_db))
        admin.execute(
            "CREATE DATABASE %s LOCALE_PROVIDER icu ICU_LOCALE %s TEMPLATE template0"
            % (config.qi(pg_db), _lit(icu)))
    finally:
        admin.close()


def apply_schema(fresh=False):
    """Aplica el esquema completo. Con fresh=True recrea la base antes."""
    pg_db = config.pg_db_name()
    d = ddl_dir()

    missing = [f for f in DDL_FILES if not os.path.exists(os.path.join(d, f + ".sql"))]
    if missing:
        raise SystemExit(
            "ERROR: faltan archivos DDL en %s: %s (ajuste DDL_DIR)"
            % (d, ", ".join(m + ".sql" for m in missing)))

    if fresh:
        print("==> DROP + CREATE de la base %s (LOCALE_PROVIDER icu %s)"
              % (pg_db, os.environ.get("PG_ICU_LOCALE", "es-ES")))
        _create_database(pg_db)

    pg = config.connect_pg(dbname=pg_db)
    try:
        print("==> Aplicando DDL a %s" % pg_db)
        for f in DDL_FILES:
            with open(os.path.join(d, f + ".sql"), encoding="utf-8") as fh:
                pg.execute(fh.read())
            print("   - %s.sql" % f)
    finally:
        pg.close()
