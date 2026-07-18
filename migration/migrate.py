#!/usr/bin/env python3
"""migrate.py - Migracion de datos Geus_ISP_DB: MS SQL Server -> PostgreSQL. 100% Python.

CLI unica. Orquesta las tres etapas usando SOLO Python (psycopg + pyodbc); no
depende de psql, sqlcmd ni pgloader:

  --schema     crea/recrea el esquema PG aplicando el DDL 00..03 (via psycopg)
  --data       copia los datos MSSQL->PG preservando PK + re-sincroniza secuencias
  --validate   reporte de integridad ORIGEN vs DESTINO (conteos, sumas, rango de PK)
  --all        las tres etapas en orden
  --fresh      junto con --schema: DROP + CREATE de la base PG (locale ICU es-ES)

Pensado para ejecutarse contra localhost (un restore de Geus_ISP_DB en MSSQL + un
PostgreSQL 18), como paso previo a las pruebas manuales del sandbox. NO apunta a
produccion.

Config por variables de entorno o un archivo .env junto a este script (ver
.env.example). Requiere un venv con pyodbc + psycopg (ver requirements.txt) y el
"ODBC Driver 18 for SQL Server" instalado en el SO. Ejecute check_requirements.py
primero para verificar los prerrequisitos.

Ejemplos:
    python -m venv .venv
    .venv/bin/pip install -r requirements.txt        # Windows: .venv\\Scripts\\pip
    cp .env.example .env                             # y edite credenciales

    .venv/bin/python migrate.py --all                # esquema + datos + validacion
    .venv/bin/python migrate.py --schema --fresh     # DROP+CREATE + DDL
    .venv/bin/python migrate.py --data               # solo datos + secuencias
    .venv/bin/python migrate.py --validate           # solo validar
    .venv/bin/python migrate.py --data --tables Country,State   # subconjunto

(Archivo en ASCII puro a proposito: evita mojibake en la consola de Windows.)
"""
from __future__ import annotations

import argparse
import os
import sys

# Permite `import miglib` sin importar desde donde se invoque el script.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from miglib import config, schema, etl, validate  # noqa: E402


def build_parser():
    ap = argparse.ArgumentParser(
        prog="migrate.py",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Migracion de datos Geus_ISP_DB MSSQL -> PostgreSQL con validacion integral (100% Python).")
    ap.add_argument("--all", action="store_true", help="esquema + datos + validacion")
    ap.add_argument("--schema", action="store_true", help="(re)crear el esquema PG (DDL 00..03)")
    ap.add_argument("--data", action="store_true", help="copiar datos + re-sincronizar secuencias")
    ap.add_argument("--validate", action="store_true", help="validar integridad origen vs destino")
    ap.add_argument("--fresh", action="store_true", help="con --schema: DROP + CREATE de la base PG (ICU)")
    ap.add_argument("--tables", default="", help="subconjunto de tablas por coma (solo --data)")
    ap.add_argument("--batch", type=int, default=5000, help="filas por lote de lectura MSSQL (default 5000)")
    ap.add_argument("--no-truncate", action="store_true", help="no truncar el destino antes de copiar")
    ap.add_argument("--no-reset-sequences", action="store_true", help="no re-sincronizar secuencias al final")
    ap.add_argument("--detail", action="store_true",
                    help="con --validate: imprime detalle por tabla y escribe out/validation_report.csv")
    ap.add_argument("--env-file", default="", help="ruta a un .env (default: .env junto a este script)")
    return ap


def main(argv=None):
    ap = build_parser()
    args = ap.parse_args(argv)

    here = os.path.dirname(os.path.abspath(__file__))
    config.load_env(args.env_file or os.path.join(here, ".env"))

    do_schema = args.all or args.schema
    do_data = args.all or args.data
    do_validate = args.all or args.validate

    if not (do_schema or do_data or do_validate):
        ap.print_help()
        print("\nNada que hacer. Elija al menos una etapa: --all | --schema | --data | --validate")
        return 2

    if do_schema:
        schema.apply_schema(fresh=args.fresh)

    if do_data:
        tables = [t for t in args.tables.split(",") if t.strip()] or None
        etl.copy_data(
            tables=tables,
            truncate=not args.no_truncate,
            batch=args.batch,
            reset=not args.no_reset_sequences,
        )

    if do_validate:
        print()
        ok = validate.validate(detail=args.detail)
        return 0 if ok else 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
