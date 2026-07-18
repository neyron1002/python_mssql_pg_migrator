# Geus_ISP_DB — DDL definitivo PostgreSQL

DDL de la base `Geus_ISP_DB` (contexto `IspDbContext`) tras su migración de
MS SQL Server a **PostgreSQL 18** (proveedor de locale **ICU**). Es la fuente
de esquema tanto para el tier de tests de integración Testcontainers
(`ISP.Api.IntegrationTests`) como para la creación de la BD en el servidor.

Arquitectura de **motores mixtos**: solo `IspDb` corre en PostgreSQL; el resto
de las bases sigue en MS SQL Server (salvo Audit / Attachment /
SupportTicketAttachment, ya migradas en ciclos anteriores).

## Orden de aplicación

Los scripts se aplican **en orden numérico** (así los ejecuta el fixture de
tests, `PostgresIspDbFixture.ApplyDdlAsync`):

| # | Archivo | Contenido |
|---|---|---|
| 00 | `00_init.sql` | Extensión `pgcrypto` (para `gen_random_uuid()`) + colación ICU `spanish_ci_as` (`es-ES-u-ks-level2`, `deterministic=false`) = análogo case-insensitive / accent-sensitive de MSSQL `*_CI_AS`. |
| 01 | `01_schema.sql` | 57 tablas: PK, FK, índices, defaults. Generado desde `IspDbContext` con proveedor Npgsql (fiel al runtime). |
| 02 | `02_constraints_indexes.sql` | Aplica la colación CI a `PersonEmail.Email` (lookup por igualdad → login/email case-insensitive). Notas de índices de performance opcionales del corpus. |
| 03 | `03_views.sql` | 24 vistas. |

## Provisión del clúster (servidor)

El clúster / la BD debe crearse con proveedor de locale ICU y locale `es-ES`:

```
POSTGRES_INITDB_ARGS="--locale-provider=icu --icu-locale=es-ES"
```

La colación `spanish_ci_as` (case-insensitive) se define en `00_init.sql` y se
aplica selectivamente a columnas de igualdad en `02`. La búsqueda por substring
sensible a mayúsculas se resuelve en la capa de consulta con `ILIKE`
(`PlanServiceRepository.PaginatePlanServiceAsync`), no vía colación de columna
(PostgreSQL no soporta `LIKE` sobre colación no determinista).

## Creación manual / entorno de prueba local

Los scripts `00`–`03` corren **dentro** de la base ya creada; ninguno ejecuta
`CREATE DATABASE` (eso lo hace el tooling / Testcontainers). Para crear la base
**a mano** y aplicar todo el DDL en un entorno local, hay dos ayudas en esta
misma carpeta:

| Archivo | Qué hace |
|---|---|
| `create_local_db.sql` | Bootstrap de `psql`: `DROP`/`CREATE DATABASE "Geus_ISP_DB"` con locale ICU `es-ES` desde `template0`, y aplica `00`→`03` con `\ir`. Re-ejecutable (usa `DROP ... WITH (FORCE)`). |
| `create_local_db.sh` | Wrapper turnkey. Modo `--docker` (por defecto) levanta `postgres:18` con el mismo locale ICU `es-ES` que la suite de integración y aplica el DDL; modo `--local` usa el `psql` del host contra un servidor existente. |

**Turnkey con Docker (no requiere `psql` en el host):**

```bash
./create_local_db.sh                 # levanta postgres:18 y crea Geus_ISP_DB
# Conexión: postgresql://postgres:postgres@localhost:5432/Geus_ISP_DB
# (override: HOST_PORT=..., CONTAINER=..., PG_PASSWORD=...)
```

**Contra un servidor PostgreSQL ya existente** (con `psql` en el host, conectado
a una BD de mantenimiento como `postgres`, no a `Geus_ISP_DB`):

```bash
psql -v ON_ERROR_STOP=1 -U postgres -h localhost -d postgres -f create_local_db.sql
#   o bien:  ./create_local_db.sh --local     # usa variables PG* estándar
```

El clúster destino debería estar inicializado con proveedor de locale ICU
`es-ES`; el modo `--docker` ya lo hace. Resultado esperado: 57 tablas, 24
vistas, colación `spanish_ci_as` aplicada a `PersonEmail.Email`.

## Génesis y reconciliación

- `01_schema.sql` se generó desde el modelo EF (`GenerateCreateScript()` con
  Npgsql), garantizando paridad exacta con lo que el runtime espera.
- Reconciliado contra el corpus probado en `ia-assets/pg-migration/`
  (gitignorado): DDL MSSQL original + PG probado (`_to_PG.psql`,
  `_Index_PG.psql`, `_missing_index_PG.psql`).

## Pendientes (needs-human) antes del cutover

- Migración de **datos** de las filas de `Report.Query` (T-SQL almacenado como
  dato → equivalente PG) previa al cutover.
- Verificación de los **cuerpos reales de las 24 vistas** + sinónimos + procs
  contra la BD viva (RS v002 §5).
- Runbook de **cutover / rollback** y sincronización de datos (p. ej. pgloader)
  — fuera del alcance de este ciclo.
- Índices de performance del corpus `ia-assets/pg-migration/*_Index_PG.psql` /
  `*_missing_index_PG.psql`: plegarlos en `02` una vez validados los nombres de
  columna generados (no requeridos para corrección ni para la suite).
