# Migración de datos `Geus_ISP_DB` — MS SQL Server → PostgreSQL (100% Python)

Toolkit **enteramente en Python** para **migrar los datos** de `Geus_ISP_DB` de
MSSQL a PostgreSQL y **validar la integridad** de la migración tabla a tabla, como
paso previo a las pruebas manuales del sandbox pre-producción.

Una **sola CLI** (`migrate.py`) orquesta las tres etapas usando únicamente Python
(`psycopg` + `pyodbc`). **No depende de `psql`, `sqlcmd` ni `pgloader`.**

> **No apunta a producción.** Se ejecuta contra un *restore* de `Geus_ISP_DB` en un
> MSSQL y un PostgreSQL 18 accesibles desde la máquina que corre el script
> (por ejemplo el Windows Server donde están instalados ambos motores).

## Qué hace

De forma **schema-driven** (sin hardcodear las 57 tablas):

1. **`--schema`** — crea la base PostgreSQL (locale ICU `es-ES`) y aplica el DDL
   definitivo `../postgres/geus_isp_db/00..03` **vía psycopg** (no `psql`).
2. **`--data`** — copia los datos MSSQL→PG **preservando los PK con su valor exacto**,
   **deshabilita las FK** durante la carga (`session_replication_role=replica`), y
   **re-sincroniza las secuencias identity** (todo con psycopg, sin `psql`) para que
   el próximo `INSERT` de la app no colisione con un PK migrado. La copia usa el
   protocolo **COPY** de psycopg (maneja el escaping de texto/JSON internamente).
3. **`--validate`** — genera en Python un reporte de integridad de **origen** y
   **destino** y los compara en memoria:
   - **conteos** de filas por tabla,
   - **sumatorias** de cada columna numérica exacta (money/decimal/enteros),
   - **rango de PK** (`min`/`max`) de cada PK entero → identificadores preservados 1:1,
   - **tabla a tabla**, con reporte de discrepancias y exit code (0=íntegra, 1=falla).

`--all` corre las tres en orden; `--fresh` (con `--schema`) hace `DROP + CREATE`
de la base PG.

## Archivos

```
database/migration/
├── migrate.py               # CLI única (schema / data / validate) — punto de entrada
├── check_requirements.py    # verifica prerrequisitos (correr PRIMERO)
├── requirements.txt         # pyodbc + psycopg[binary]
├── .env.example             # plantilla de credenciales (copiar a .env)
└── miglib/                  # paquete de soporte (todo Python)
    ├── config.py            # carga de .env + conexiones (psycopg / pyodbc)
    ├── schema.py            # crear la base PG (ICU) + aplicar DDL 00..03
    ├── etl.py               # copia de datos + reset de secuencias (COPY)
    └── validate.py          # reporte de integridad + comparación origen vs destino
```

El DDL sigue viviendo (y siendo la fuente de verdad) en
`../postgres/geus_isp_db/00..03.sql`; este toolkit solo lo aplica.

---

## Requisitos

| Requisito | Para qué | Notas |
|---|---|---|
| **Python 3.8+** | ejecutar todo | `python.org` en Windows (marque *Add python.exe to PATH*) |
| **psycopg (v3)** | conexión/COPY a PostgreSQL | `pip install -r requirements.txt` |
| **pyodbc** | leer el MSSQL origen | `pip install -r requirements.txt` |
| **ODBC Driver 18 for SQL Server** | driver que usa pyodbc | ver por SO abajo |

**Driver ODBC de SQL Server** (lo necesita `pyodbc`):

- **Windows** — instale el *Microsoft ODBC Driver 18 for SQL Server*. El
  *Driver Manager* de Windows es nativo, así que pyodbc funciona sin nada más.
- **Linux** — instale `unixodbc` **y** el paquete `msodbcsql18` de Microsoft
  (el wheel de pyodbc necesita `libodbc.so.2` de unixODBC en tiempo de ejecución).
- **macOS** — `brew install unixodbc` y el `msodbcsql18` de Microsoft (Homebrew tap).

Ajuste `MSSQL_ODBC_DRIVER` / `MSSQL_ODBC_EXTRA` en el `.env` si su SO tiene el
*Driver 17* en vez del 18, o necesita otros parámetros de conexión.

## Instalación

```bash
cd database/migration

# 1) venv + dependencias
python -m venv .venv
.venv/bin/pip install -r requirements.txt        # Windows: .venv\Scripts\pip install -r requirements.txt

# 2) credenciales
cp .env.example .env                             # Windows: Copy-Item .env.example .env
#   edite .env con las credenciales de origen (MSSQL) y destino (PostgreSQL)

# 3) verifique prerrequisitos (incluye conectividad con --connect)
.venv/bin/python check_requirements.py           # Windows: .venv\Scripts\python check_requirements.py
.venv/bin/python check_requirements.py --connect # además prueba conectar a PG y MSSQL
```

## Uso

```bash
# Linux/macOS: .venv/bin/python   |   Windows: .venv\Scripts\python
.venv/bin/python migrate.py --all                # esquema + datos + validación
.venv/bin/python migrate.py --schema --fresh     # DROP+CREATE de la base PG + DDL
.venv/bin/python migrate.py --data               # solo copiar datos + secuencias
.venv/bin/python migrate.py --validate           # solo validar (resumen PASS/FAIL)
.venv/bin/python migrate.py --validate --detail  # + tabla por-tabla + out/validation_report.csv
.venv/bin/python migrate.py --data --tables Country,State   # subconjunto de tablas
```

Opciones adicionales de `--data`: `--no-truncate` (no vaciar el destino antes),
`--no-reset-sequences` (no re-sincronizar secuencias), `--batch N` (filas por lote
de lectura, default 5000). `--env-file RUTA` usa otro `.env`.

**`--detail` (con `--validate`)**: por defecto la validación solo imprime el
resumen (tablas en común / OK / con discrepancia) y el detalle **solo** cuando hay
discrepancias. Con `--detail` imprime **siempre** una línea por tabla (filas
origen=destino, sumas OK, rango de PK, estado) y vuelca **todas** las métricas
(rowcount + `sum:*` + `pkmin/pkmax:*`) a `out/validation_report.csv` como evidencia
archivable — útil para adjuntar la prueba de que cada tabla cuadró, no solo el
veredicto.

### Topología típica (Windows Server)

El proceso corre **directamente en el Windows Server** donde están los motores. Si
MSSQL y/o PostgreSQL corren **en contenedores** en ese servidor, publique sus
puertos al host y apunte el `.env` a `localhost:<puerto-publicado>` — el script se
conecta por red a esos puertos, no necesita entrar a los contenedores. Como todo va
por ODBC (MSSQL) y el protocolo de PostgreSQL (psycopg), **no hay dependencia de la
red interna de Docker** (`host.docker.internal`, etc.).

## Configuración (`.env`)

```
MSSQL_HOST MSSQL_PORT MSSQL_DB MSSQL_USER MSSQL_PASS   # origen
PG_HOST    PG_PORT    PG_DB    PG_USER    PG_PASS      # destino (PG 18 con ICU)
MSSQL_ODBC_DRIVER  MSSQL_ODBC_EXTRA                    # driver ODBC (opcional)
PG_ICU_LOCALE  PG_ADMIN_DB  DDL_DIR                    # opcionales
```

## Notas y garantías

- **PK preservados 1:1.** Las columnas identity son `GENERATED BY DEFAULT AS
  IDENTITY`, así que se insertan los PK con su valor original; `reset_sequences`
  deja cada secuencia en `MAX(pk)` (siguiente id = `MAX+1`).
- **Escaping seguro.** La copia usa el protocolo **COPY** de psycopg: el texto libre
  con comas/comillas/saltos de línea y los blobs JSON (`JsonParameters`, `Query`)
  viajan intactos (verificado con round-trip byte a byte).
- **Las 24 vistas `VContractCompany*` NO migran datos** (una vista no tiene datos:
  se recrea con el DDL). ⚠️ Hoy son *placeholders* `WHERE false` — su lógica real es
  un pendiente aparte (Linear **JUA-261**); no afecta la validación de datos, que
  cubre solo tablas base.
- **Columna aproximada excluida.** `InvoiceDetail.Quantity` es `double precision`
  (no comparable exacto cross-engine); se excluye de las sumatorias en **ambos**
  lados automáticamente (por tipo). Todo lo demás (money→numeric, decimal, enteros)
  se suma y compara exacto (en MSSQL con `CAST(... AS decimal(38, escala))` para no
  truncar ni desbordar).
- El **destino PostgreSQL 18** se crea con `LOCALE_PROVIDER icu ICU_LOCALE 'es-ES'`
  (requiere soporte ICU, estándar en las imágenes oficiales).
- **FK durante la carga.** Se deshabilitan con `session_replication_role=replica` en
  la sesión del ETL, lo que requiere que `PG_USER` sea **superusuario**.

## Estado de verificación

Probado contra un **PostgreSQL 18 real**: creación de la base ICU, aplicación del
DDL 00..03 vía psycopg (57 tablas + 24 vistas), preservación de PK con reset de
secuencias, round-trip de COPY con texto/JSON conflictivo, y el reporte de
integridad + comparación (casos PASS y FAIL). El **lado MSSQL** (lectura vía pyodbc,
conversión de `uniqueidentifier`→`uuid`, y las sumas/conteos con SQL estándar) se
valida en tu servidor con el origen real; `--validate` es la red de seguridad que
detecta cualquier fila/valor/identificador que no haya migrado bien.
