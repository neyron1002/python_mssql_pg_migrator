-- Report: 4
-- Title: Materiales
-- TableName: SupporTicket
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=4)
-- Notes: T-SQL usaba JSON_QUERY(JSONPayLoad,'$.materials') + `cross apply openjson(...)
--   WITH (...)` para explotar el array "materials" del JSONPayload de SupportTicket;
--   traducido a `"JSONPayload"::jsonb -> 'materials'` + `cross join lateral
--   jsonb_to_recordset(...)` (patron recomendado en CONVENTIONS.md (f) para OPENJSON).
--   GOTCHA encontrado en autovalidacion (probando las 4 formas posibles del valor de
--   "materials" -- clave ausente / null explicito / array vacio / array poblado):
--   un `coalesce(x -> 'materials', '[]'::jsonb)` NO alcanza, porque cuando la clave
--   SI existe pero su valor es el literal JSON `null` (`"materials": null`), `x ->
--   'materials'` devuelve un jsonb que REPRESENTA null (no un SQL NULL) -- COALESCE
--   no lo sustituye, y `jsonb_to_recordset(<jsonb null>)` lanza `cannot call
--   jsonb_to_recordset on a non-array` (confirmado empiricamente). Se usa en su
--   lugar `case when jsonb_typeof(x -> 'materials') = 'array' then x -> 'materials'
--   else '[]'::jsonb end`, que cubre uniformemente clave-ausente (jsonb_typeof(SQL
--   NULL)=SQL NULL, no 'array') y null-explicito (jsonb_typeof('null'::jsonb)='null',
--   no 'array') -> ambos caen al '[]'::jsonb -> jsonb_to_recordset('[]') -> 0 filas
--   sin error, igual que CROSS APPLY OPENJSON(NULL) en T-SQL (T-SQL: JSON_QUERY
--   sobre un escalar/null devuelve SQL NULL, no un objeto JSON "null" -- por eso el
--   T-SQL original nunca pasaba un jsonb-null a OPENJSON; el equivalente PG debe
--   normalizar explicitamente ese caso para no fallar en tiempo de ejecucion). Los
--   dos niveles de
--   subconsulta T-SQL ("SELECT JSON_QUERY... FROM SupportTicket" + "SELECT IdCompany,
--   IdContract, ... FROM (...) T1 cross apply openjson(...)") se colapsan en un unico
--   nivel "com" (misma proyeccion de columnas resultante, sin cambio semantico).
--   `com` (alias fijo del motor para {WHERE1}) resuelve directo contra
--   "SupportTicket"."IdCompany" (uuid, PascalCase, sin conflicto de case).
--   sum("quantity") en PG retorna bigint (quantity es int) -> cast (::int) explicito
--   segun CONVENTIONS.md (e) porque JsonParameters.Column["qty"].Type=System.Int32.
-- JsonParameters: {     "Column":[        {           "Name":"name",           "Title":"Material",           "Type":"System.String",           "Format":""        },        {           "Name":"qty",           "Title":"cantidad",           "Type":"System.Int32",           "Format":""        }     ],     "Filter":{        "Geographic":true,        "CorporateLocation":false,        "Employee":true,        "Date":false,        "DateRange":true,        "DateTimeRange":false,        "Debt":false     }  }
---
select
  "idMaterial"::text as "idMaterial",
  "name"::text as "name",
  (sum("quantity"))::int as "qty"
from (
  select
    com."IdCompany",
    com."IdEmployee",
    com."IdContract",
    com."Schedule_Date" as "Date",
    com."idMaterial",
    com."name",
    com."quantity"
  from (
    select
      t1."IdCompany",
      t1."IdContract",
      t1."IdSupportTicket",
      t1."IdEmployee",
      t1."Schedule_Date",
      mat."idMaterial",
      mat."name",
      mat."quantity"
    from (
      select
        "IdSupportTicket",
        "IdContract",
        "IdCompany",
        "IdEmployee",
        "DateCreate",
        "Schedule_Date",
        "IdTermTicketScheduleType",
        case when jsonb_typeof("JSONPayload"::jsonb -> 'materials') = 'array'
             then "JSONPayload"::jsonb -> 'materials'
             else '[]'::jsonb
        end as json
      from "SupportTicket"
      where "JSONPayload" is not null
        and "Done" = true
        and "IdTermTicketScheduleType" = 14
    ) t1
    cross join lateral jsonb_to_recordset(t1.json) as mat("idMaterial" text, "name" text, "quantity" int)
  ) com
  inner join "Employee" as emp on emp."IdEmployee" = com."IdEmployee"
  inner join "Contract" on "Contract"."IdContract" = com."IdContract"
  inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
  inner join "Neighborhood" nei on nei."IdNeighborhood" = "Address"."IdNeighborhood"
  inner join "Zone" zon on zon."IdZone" = nei."IdZone"
  inner join "City" cit on cit."IdCity" = nei."IdCity"
  inner join "State" sta on sta."IdState" = cit."IdState"
  inner join "Country" cou on cou."IdCountry" = sta."IdCountry"
  {WHERE1}
) t2
{WHERE2}
group by "idMaterial", "name"
order by "name"
