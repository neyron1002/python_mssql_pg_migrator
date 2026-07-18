#!/usr/bin/env python3
"""check_requirements.py - Comprueba los prerrequisitos de migrate.py. 100% Python.

Reemplaza al viejo check-requirements.ps1. Ejecutelo con el interprete del venv:

    .venv/bin/python check_requirements.py            # Linux/macOS
    .venv\\Scripts\\python check_requirements.py        # Windows

Verifica (sin conectarse a ninguna base, salvo que pase --connect):
  - version de Python (>= 3.8)
  - psycopg (v3) importable
  - pyodbc importable y drivers ODBC disponibles (busca el "ODBC Driver 18/17 for SQL Server")
  - archivos del toolkit y el DDL 00..03
  - .env presente (aviso si falta)
  - con --connect: intenta conectar a PostgreSQL y a MS SQL Server con el .env

Exit code 0 = listo | 1 = falta algun requisito critico.

(Archivo en ASCII puro a proposito.)
"""
from __future__ import annotations

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

OK = "  [OK]  "
BAD = " [FALTA]"
WARN = "  [--]  "


def line(mark, label, detail, hint=""):
    print("%s %-16s %s" % (mark, label, detail))
    if mark != OK and hint:
        print("           -> %s" % hint)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Verifica prerrequisitos de migrate.py (100% Python).")
    ap.add_argument("--connect", action="store_true",
                    help="ademas, intenta conectar a PG y MSSQL usando el .env")
    ap.add_argument("--env-file", default="", help="ruta a un .env (default: .env junto a este script)")
    args = ap.parse_args(argv)

    print("=" * 71)
    print(" Requisitos - Migracion Geus_ISP_DB  (MSSQL -> PostgreSQL, 100% Python)")
    print("=" * 71)

    missing = []

    # ---- Python ----
    print("\nEntorno")
    pyv = sys.version_info
    py_ok = pyv >= (3, 8)
    line(OK if py_ok else BAD, "Python",
         "%d.%d.%d  [%s]" % (pyv.major, pyv.minor, pyv.micro, sys.executable),
         "Se requiere Python 3.8+")
    if not py_ok:
        missing.append("Python 3.8+")
    venv = (sys.prefix != getattr(sys, "base_prefix", sys.prefix))
    line(OK if venv else WARN, "venv",
         "activo" if venv else "NO parece un venv (recomendado usar .venv)",
         "python -m venv .venv  y ejecute con .venv/bin/python (Win: .venv\\Scripts\\python)")

    # ---- Dependencias Python ----
    print("\nDependencias Python")
    try:
        import psycopg  # noqa: F401
        line(OK, "psycopg", "v%s importable" % getattr(psycopg, "__version__", "?"))
    except Exception as e:  # noqa: BLE001
        line(BAD, "psycopg", "no importable (%s)" % e,
             "pip install -r requirements.txt")
        missing.append("psycopg")

    drivers = []
    try:
        import pyodbc
        drivers = list(pyodbc.drivers())
        line(OK, "pyodbc", "v%s importable" % getattr(pyodbc, "version", "?"))
    except Exception as e:  # noqa: BLE001
        line(BAD, "pyodbc", "no importable (%s)" % e,
             "pip install -r requirements.txt")
        missing.append("pyodbc")

    # ---- Driver ODBC de SQL Server ----
    sql_drivers = [d for d in drivers if "SQL Server" in d]
    want18 = any("18" in d for d in sql_drivers)
    want17 = any("17" in d for d in sql_drivers)
    if sql_drivers:
        pref = "ODBC Driver 18 for SQL Server" if want18 else \
               ("ODBC Driver 17 for SQL Server" if want17 else sql_drivers[0])
        line(OK, "ODBC SQL Server", "%s (disponibles: %s)" % (pref, ", ".join(sql_drivers)))
        if not (want18 or want17) and drivers:
            print("           (aviso: ajuste MSSQL_ODBC_DRIVER en .env al driver exacto de arriba)")
    else:
        line(BAD, "ODBC SQL Server",
             "no hay 'ODBC Driver 1x for SQL Server' instalado" if drivers is not None else "pyodbc ausente",
             "Instale el 'ODBC Driver 18 for SQL Server' (Microsoft) para su SO")
        if "pyodbc" not in missing:
            missing.append("ODBC Driver for SQL Server")

    # ---- Archivos del toolkit ----
    print("\nArchivos del toolkit")
    expected = [
        "migrate.py",
        os.path.join("miglib", "config.py"),
        os.path.join("miglib", "schema.py"),
        os.path.join("miglib", "etl.py"),
        os.path.join("miglib", "validate.py"),
        os.path.join("..", "postgres", "geus_isp_db", "00_init.sql"),
        os.path.join("..", "postgres", "geus_isp_db", "01_schema.sql"),
        os.path.join("..", "postgres", "geus_isp_db", "02_constraints_indexes.sql"),
        os.path.join("..", "postgres", "geus_isp_db", "03_views.sql"),
    ]
    for rel in expected:
        p = os.path.join(HERE, rel)
        exists = os.path.exists(p)
        line(OK if exists else BAD, os.path.basename(rel), rel,
             "Ejecute este script DENTRO de database/migration/ del repo")
        if not exists:
            missing.append(rel)

    # ---- .env ----
    print("\nConfiguracion")
    env_path = args.env_file or os.path.join(HERE, ".env")
    env_ok = os.path.exists(env_path)
    line(OK if env_ok else WARN, ".env",
         env_path if env_ok else "no existe (copie .env.example a .env y edite credenciales)",
         "cp .env.example .env   (Windows: Copy-Item .env.example .env)")

    # ---- Conectividad opcional ----
    if args.connect:
        print("\nConectividad (--connect)")
        from miglib import config
        config.load_env(env_path)
        try:
            pg = config.connect_pg()
            ver = pg.execute("SELECT version()").fetchone()[0].split(",")[0]
            pg.close()
            line(OK, "PostgreSQL", ver)
        except Exception as e:  # noqa: BLE001
            line(BAD, "PostgreSQL", "no conecta (%s)" % str(e).splitlines()[0][:120])
            missing.append("conexion PostgreSQL")
        try:
            ms = config.connect_mssql()
            cur = ms.cursor()
            cur.execute("SELECT @@VERSION")
            ver = str(cur.fetchone()[0]).splitlines()[0]
            ms.close()
            line(OK, "MS SQL Server", ver[:80])
        except Exception as e:  # noqa: BLE001
            line(BAD, "MS SQL Server", "no conecta (%s)" % str(e).splitlines()[0][:120])
            missing.append("conexion MS SQL Server")

    # ---- Resumen ----
    print("\n" + "=" * 71)
    uniq = []
    for m in missing:
        if m not in uniq:
            uniq.append(m)
    if not uniq:
        print(" RESULTADO: LISTO - prerrequisitos criticos presentes.")
        print(" Siguiente: cp .env.example .env, edite credenciales y ejecute:")
        print("   .venv/bin/python migrate.py --all      (Windows: .venv\\Scripts\\python)")
        print("=" * 71)
        return 0
    print(" RESULTADO: FALTAN requisitos criticos:")
    for m in uniq:
        print("   - %s" % m)
    print(" Instale lo que falta (ver sugerencias) y vuelva a ejecutar.")
    print("=" * 71)
    return 1


if __name__ == "__main__":
    sys.exit(main())
