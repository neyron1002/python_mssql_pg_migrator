"""config.py - Carga de .env y conexiones a ambos motores.

MSSQL: pyodbc (ODBC Driver 18 for SQL Server). PostgreSQL: psycopg (v3).
Ambos imports son PEREZOSOS: la etapa que solo toca PostgreSQL no necesita
pyodbc instalado, y viceversa.

(Archivo en ASCII puro a proposito: evita mojibake en la consola de Windows.)
"""
from __future__ import annotations

import os
import sys
import uuid


# --------------------------------------------------------------------- entorno
def load_env(path):
    """Carga un .env (KEY=VALUE) sin pisar variables de entorno ya definidas."""
    if not path or not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip())


def require(name):
    v = os.environ.get(name)
    if not v:
        sys.exit("ERROR: variable %s sin definir (ver .env.example)" % name)
    return v


def pg_db_name():
    return os.environ.get("PG_DB", "Geus_ISP_DB")


def qi(ident):
    """Cita un identificador PostgreSQL (comillas dobles, duplicando las internas)."""
    return '"%s"' % ident.replace('"', '""')


# ------------------------------------------------------------------ conexiones
def _guid_converter(value):
    """uniqueidentifier de MSSQL -> uuid.UUID (pyodbc lo entrega como bytes LE)."""
    if value is None:
        return None
    if isinstance(value, (bytes, bytearray)):
        return uuid.UUID(bytes_le=bytes(value))
    return uuid.UUID(str(value))


def connect_mssql():
    """Conexion al ORIGEN MS SQL Server via pyodbc."""
    import pyodbc  # import perezoso: la ruta PG-only no lo necesita
    drv = os.environ.get("MSSQL_ODBC_DRIVER", "ODBC Driver 18 for SQL Server")
    extra = os.environ.get("MSSQL_ODBC_EXTRA", "TrustServerCertificate=yes;Encrypt=no")
    cs = (
        "DRIVER={%s};SERVER=%s,%s;DATABASE=%s;UID=%s;PWD=%s;%s"
        % (drv, require("MSSQL_HOST"), os.environ.get("MSSQL_PORT", "1433"),
           require("MSSQL_DB"), require("MSSQL_USER"), require("MSSQL_PASS"), extra)
    )
    conn = pyodbc.connect(cs)
    # -11 = SQL_GUID; convierte uniqueidentifier a uuid.UUID
    conn.add_output_converter(pyodbc.SQL_GUID, _guid_converter)
    return conn


def connect_pg(dbname=None):
    """Conexion al DESTINO PostgreSQL via psycopg (autocommit)."""
    import psycopg  # import perezoso
    conn = psycopg.connect(
        host=require("PG_HOST"), port=os.environ.get("PG_PORT", "5432"),
        dbname=dbname or pg_db_name(),
        user=require("PG_USER"), password=require("PG_PASS"),
    )
    conn.autocommit = True
    return conn
