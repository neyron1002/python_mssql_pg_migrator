# Reportes dinámicos de IspDb — queries PostgreSQL

Artefacto versionado de las **20 queries de los reportes dinámicos de producción**
de `IspDb` (`Geus_ISP_DB`), traducidas de T-SQL (SQL Server) a PostgreSQL.

## Propósito

Cada reporte dinámico de la plataforma se define en la tabla `Report`, cuya
columna `Query` almacena una **plantilla SQL como DATO** (no como código): el
motor de reportes la lee, le inyecta filtros y la ejecuta contra la base del
tenant. Con la migración de IspDb a PostgreSQL, ese T-SQL almacenado dejó de
ser ejecutable (identificadores sin comillas que PostgreSQL pliega a
minúsculas, `ISNULL`, `FORMAT`, `DATEADD`, `FOR XML PATH`, lotes
multi-sentencia con `#temp`, etc.). Este directorio cumple dos funciones:

1. **Fuente de verdad versionada** de las 20 queries PG traducidas (un archivo
   `NN_<slug>.sql` por reporte). El dump TSV original vive en `ia-assets/`
   (gitignorado); estos artefactos son la copia committeada y auditable.
2. **Entregable de migración de datos** de `Report.Query`: el script
   `_apply_report_queries.sql` proyecta estas queries sobre la tabla `Report`
   de la base ya migrada a PostgreSQL (un `UPDATE ... WHERE "IdReport" = N`
   por reporte).

Los tests de integración (`ISP.Api.IntegrationTests/Reports/`) consumen estos
mismos archivos para verificar, contra un PostgreSQL real (Testcontainers,
`PostgresIspDbFixture`), que cada query ejecuta sin error de dialecto o
identificador (mitigación del riesgo **R2**: "los reportes caen en silencio").

## Contrato del motor

El motor es `ISP.Api.Data/Repositories/ReportsRepository.cs`
(`GetResultReportAsync` → `GetQueryWithFilter`). Cada query traducida DEBE
respetar este contrato:

### Placeholders (se dejan LITERALES en el artefacto; los resuelve el motor)

- **`{WHERE1}`** — filtro geográfico / corporativo. El motor lo reemplaza, en
  **todas** sus ocurrencias, por:

  ```
  where com."IdCompany" = @IdCompany
  ```

  más, condicionalmente (si el request trae el valor), cualquiera de estos
  `and` con **alias fijos, en minúscula y SIN comillas**:

  | alias | condición inyectada          |
  |-------|------------------------------|
  | `com` | `com."IdCompany" = @IdCompany` (siempre) |
  | `cou` | `and cou."IdCountry" = @IdCountry` |
  | `sta` | `and sta."IdState" = @IdState` |
  | `cit` | `and cit."IdCity" = @IdCity` |
  | `nei` | `and nei."IdNeighborhood" = @IdNeighborhood` |
  | `zon` | `and zon."IdZone" = @IdZone` |
  | `bra` | `and bra."IdBranchCompany" = @IdBranchCompany` |
  | `ofi` | `and ofi."IdOffice" = @IdOffice` |
  | `cas` | `and cas."IdCashRegister" = @IdCashRegister` |
  | `emp` | `and emp."IdEmployee" = @IdEmployee` |

  Toda tabla/subconsulta que participe del `{WHERE1}` debe alias-earse
  exactamente así. `com` es siempre la tabla base que tiene `"IdCompany"`
  (p.ej. `Company`, `Contract`, `Voucher`, `SupportTicket`, `Employee`,
  `OnlinePay`). Cada reporte expone solo los aliases geográficos que su
  cadena de JOINs realmente contiene (si el reporte no une `Country`, no
  soporta filtro por país — comportamiento heredado del T-SQL original, no
  se inventan JOINs nuevos).

- **`{WHERE2}`** — filtro genérico sobre columnas de salida canónicas, sin
  alias de tabla. El motor lo reemplaza por cero o más condiciones (o cadena
  vacía si el usuario no filtró):

  ```
  where  "Date" = @Date
  where/and  "Date" between @InitDate and @FinishDate
  where/and  "Debt" between @InitDebt and @FinishDebt
  where/and  "NotPay" between @InitNotPayment and @FinishNotPayment
  where/and  "DateTime" between @InitDateTime and @FinishDateTime
  ```

  La subconsulta que envuelve `{WHERE2}` debe exponer, citada, la columna
  canónica que el reporte usa (`"Date"` / `"Debt"` / `"NotPay"` /
  `"DateTime"`). Con `{WHERE2}` vacío la query debe seguir siendo válida.

Todos los valores viajan como `NpgsqlParameter` tipados — **nunca** se
interpolan literales (preserva el fix de inyección SQL, AUDIT S-4).

### Alias de salida (contrato con `JsonParameters.Column[]`)

El `SELECT` final debe exponer **una columna por cada `Column[i].Name`**, con
alias citado **exacto y sensible a mayúsculas** tal como aparece en el JSON
(en este corpus casi siempre camelCase: `AS "contractConsecutive"`,
`AS "debt"`, …). EF Core mapea por nombre de propiedad generado desde ese
string; un case distinto o un alias duplicado rompe el mapeo dinámico. Si el
reporte trabaja a nivel de contrato y `Filter.CustomFields = true`, el motor
añade en runtime una columna `IdContract` (`long`) — el SELECT final la
proyecta.

### Una sola sentencia (nada de lotes)

`FromSqlRaw` con parámetros fuerza a Npgsql al protocolo extendido, que en
PostgreSQL acepta **una única sentencia**. Los reportes que en T-SQL eran un
lote `SELECT ... INTO #Temp ...` se reescriben a una sola sentencia con
`WITH ... AS (...)` (CTEs encadenadas); las líneas `DROP TABLE #x` se
eliminan.

## Formato del header de cada `NN_<slug>.sql`

```
-- Report: <IdReport>
-- Title: <Title verbatim>
-- TableName: <TableName verbatim, con typos si los hay>
-- Category: <IdTermReportCategory>
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=<N>)
-- NeedsHuman: <motivo preciso — SOLO si aplica>
-- Notes: <notas de traducción, opcional>
-- JsonParameters: <el JSON de la fila, en una sola línea, verbatim>
---
<query PG multilínea, con {WHERE1}/{WHERE2} LITERALES>
```

La línea `---` (tres guiones) separa metadatos de la query.

## Cómo los validan los tests de integración

`ISP.Api.IntegrationTests/Reports/` levanta un `postgres:18` (ICU es-ES) vía
`PostgresIspDbFixture`, aplica el DDL committeado
(`database/postgres/geus_isp_db/00..03`) y, por cada reporte **sin
NeedsHuman**:

- **Cobertura núcleo (R2):** neutraliza los placeholders (`{WHERE1}` →
  `where com."IdCompany" = <guid>`, `{WHERE2}` → vacío) y ejecuta la query
  completa: debe correr sin error de dialecto/identificador. Sobre una vista
  temporal de esa query valida que cada `Column[].Name` existe con case
  exacto, tipo compatible y sin duplicados; además ejercita la forma con
  `{WHERE2}` activo (filtro real de fecha/deuda).
- **End-to-end (subconjunto):** siembra datos mínimos y ejecuta
  `ReportsRepository.GetResultReportAsync(...)` para assertir forma y valores.

Los reportes NEEDS-HUMAN se asertan como "documentados/excluidos", no se
ejecutan (dependen de objetos ausentes del DDL).

## Los 20 reportes

| IdReport | Título | Archivo | Estado |
|---:|---|---|---|
| 1 | Deuda por Contrato TODOS | `01_deuda-por-contrato-todos.sql` | OK |
| 2 | Deuda por Contrato SOLO ACTIVOS | `02_deuda-por-contrato-activos.sql` | **NEEDS-HUMAN** — depende de 3 vistas ausentes del DDL (`VContractPayerBehavior`, `VContractNonPaymentCut`, `VContractConnectionStatus`), que aportan `payerClassification`/`avgDaysToPay`/`hasCortesPorMora`/`cortesCount`, etc. El DDL solo define las 24 vistas placeholder `VContractCompany*`. Sin esas 3 vistas la query falla en runtime. |
| 3 | Deuda por Contrato SOLO INACTIVOS | `03_deuda-por-contrato-inactivos.sql` | OK |
| 4 | Materiales | `04_materiales.sql` | OK |
| 5 | Materiales Detallado | `05_materiales-detallado.sql` | OK |
| 6 | Pagos Online | `06_pagos-online.sql` | OK |
| 7 | Cierre de cajas C | `07_cierre-de-cajas.sql` | OK |
| 8 | Support Ticket Ejecutado Detallado | `08_support-ticket-ejecutado-detallado.sql` | OK — el único join inter-base (`Geus_ISP_Audit_DB.dbo.Audit`) ya venía COMENTADO en el T-SQL original, así que no bloquea. |
| 9 | Support Ticket Solicitado Detallado | `09_support-ticket-solicitado-detallado.sql` | OK — ídem R8 (join a `Audit` comentado en origen). |
| 10 | Reporte Especial FE | `10_reporte-especial-fe.sql` | OK |
| 11 | Usuarios Activos por Zona y Servicio | `11_usuarios-activos-por-zona-y-servicio.sql` | OK — sin `{WHERE2}` (`where2Count=0` en meta; no se inventa el placeholder). |
| 12 | Tecnicos Reportando | `12_tecnicos-reportando.sql` | OK |
| 13 | Reporte de Gastos Detallado | `13_reporte-de-gastos-detallado.sql` | OK |
| 14 | Reporte de Pagos NEQUI Detallado | `14_reporte-de-pagos-nequi-detallado.sql` | **NEEDS-HUMAN** — INNER JOIN obligatorio contra `Neyron_Nequi_DB.dbo.NequiMessage` y `Neyron_Nequi_DB.dbo.Term` (base distinta de IspDb, ausente del corpus de 57 tablas). De ahí provienen `term`/`ResponseDateTime`/`JSONMessage` y el filtro `{WHERE2}` `"Date"`. Requiere `postgres_fdw`/`dblink` o reestructuración en capa de aplicación. |
| 15 | Recaudo Detallado Incluye Notas Credito | `15_recaudo-detallado-incluye-notas-credito.sql` | **NEEDS-HUMAN** — el pipeline `#DIC`/`#DICF` lee `FROM Neyron_DI_DB.dbo.DigitalInvoice` (base distinta de IspDb, ausente del DDL), que alimenta las columnas FE `dip`/`dic`/`tdi` vía LEFT JOIN. El core de recaudo está traducido; `DigitalInvoice` debe provisionarse para correr end-to-end. |
| 16 | Reporte BANCOLOMBIA | `16_reporte-bancolombia.sql` | OK — sin `{WHERE2}` (`where2Count=0`). |
| 17 | Recaudo por Oficina | `17_recaudo-por-oficina.sql` | OK |
| 18 | Recaudo por Oficina, Cajero y Medio de Pago | `18_recaudo-por-oficina-cajero-y-medio-de-pago.sql` | OK |
| 19 | Recaudo por Oficina, Cajero y Servicio | `19_recaudo-por-oficina-cajero-y-servicio.sql` | OK |
| 20 | Recaudo por Fecha y Oficina | `20_recaudo-por-fecha-y-oficina.sql` | OK |

**Resumen:** 17 OK · 3 NEEDS-HUMAN (2, 14, 15). Los 17 OK están validados
contra el esquema real (`postgres:18`, DDL 00..03, 57 tablas + 24 vistas):
ejecutan sin error, exponen exactamente los `Column[].Name` declarados con
tipos compatibles y sin duplicados. Los 3 NEEDS-HUMAN quedan traducidos en
todo lo traducible, con la dependencia irreducible aislada y comentada; se
excluyen de `_apply_report_queries.sql`.

## `_apply_report_queries.sql`

Script de migración de datos. Amplía `Report."Query"` de
`character varying(6000)` a `text` (la query más larga son 9584 chars, R9) y
emite un `UPDATE "Report" SET "Query" = $rq$...$rq$ WHERE "IdReport" = N;` por
cada reporte OK. Los 3 NEEDS-HUMAN quedan listados y comentados al final, con
motivo. Aplicar UNA sola vez sobre la base IspDb migrada a PostgreSQL.
