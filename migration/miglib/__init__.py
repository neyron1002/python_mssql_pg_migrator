"""miglib - toolkit 100% Python para migrar y validar Geus_ISP_DB (MSSQL -> PostgreSQL).

Modulos:
    config    -> carga de .env y conexiones (psycopg / pyodbc)
    schema    -> crear la base PG (ICU) y aplicar el DDL 00..03 via psycopg
    etl       -> copia de datos MSSQL->PG preservando PK + reset de secuencias
    validate  -> reporte de integridad origen vs destino (conteos, sumas, rango PK)

Punto de entrada: ../migrate.py  (CLI unica).  No requiere psql/sqlcmd/pgloader.
"""
