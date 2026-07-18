-- Report: 14
-- Title: Reporte de Pagos NEQUI Detallado
-- TableName: Online Pay
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=14)
-- NeedsHuman: INNER JOINs Neyron_Nequi_DB.dbo.NequiMessage + Neyron_Nequi_DB.dbo.Term (separate DB, absent from the 57-table IspDb DDL); term/ResponseDateTime/JSONMessage and the WHERE2 'Date' all originate there, so the query cannot run against Geus_ISP_DB alone.
-- Notes: All IspDb parts translated (OnlinePay subquery, Contract/Address/Neighborhood/Zone/BranchCompany/Person joins, JSON_VALUE->jsonb #>>, JSONPayLoad string_agg). Only external joins block execution; validated that the sole error is 'relation NequiMessage/Term does not exist'. Note: CorporateLocation UI must offer only BranchCompany (no Office/CashRegister aliases in FROM).
-- JsonParameters: {   "Column": [    {     "Name": "cOnlinePay",     "Title": "Codigo Pago Nequi",     "Type": "System.String",     "Format": ""    },{     "Name": "term",     "Title": "Estado Transaccion NEQUI",     "Type": "System.String",     "Format": ""    }    ,{     "Name": "branchCompanyName",     "Title": "Sucursal",     "Type": "System.String",     "Format": ""    },{     "Name": "c",     "Title": "Contrato",     "Type": "System.String",     "Format": ""    },{     "Name": "nuip",     "Title": "Nuip",     "Type": "System.Int64",     "Format": ""    },{     "Name": "pName",     "Title": "Nombre Usuario",     "Type": "System.String",     "Format": ""    },{     "Name": "fhpay",     "Title": "Fecha Hora Pago",     "Type": "System.String",     "Format": ""    },    {     "Name": "mergedValues",     "Title": "Conceptos",     "Type": "System.String",     "Format": ""    },    {     "Name": "nequiPhoneNumber",     "Title": "Telefono NEQUI",     "Type": "System.String",     "Format": ""    },    {     "Name": "onlinePayValue",     "Title": "Valor Pago",     "Type": "System.Decimal",     "Format": ""    }     ],   "Filter": {    "Geographic":false,    "CorporateLocation":true,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
-- NEEDS-HUMAN: this report INNER JOINs Neyron_Nequi_DB.dbo.NequiMessage and
-- Neyron_Nequi_DB.dbo.Term, a database that is NOT part of the 57-table IspDb
-- PG DDL. The columns term / ResponseDateTime / JSONMessage (and the WHERE2
-- "Date", derived from ResponseDateTime) all originate in that external DB, so
-- the query cannot execute against Geus_ISP_DB alone. Everything that lives in
-- IspDb (OnlinePay, Contract, Address, Neighborhood, Zone, BranchCompany,
-- Person, and the JSONPayLoad string_agg) is fully translated below; the two
-- external joins are kept in place and flagged so a human can wire up
-- dblink/postgres_fdw or a migrated NequiMessage/Term table.
SELECT
  t0."cOnlinePay"::text         AS "cOnlinePay",
  t0."term"::text               AS "term",
  t0."branchCompanyName"::text  AS "branchCompanyName",
  t0."c"::text                  AS "c",
  t0."nuip"::bigint             AS "nuip",
  t0."pName"::text              AS "pName",
  t0."fhpay"::text              AS "fhpay",
  t0."mergedValues"::text       AS "mergedValues",
  t0."nequiPhoneNumber"::text   AS "nequiPhoneNumber",
  t0."onlinePayValue"::numeric  AS "onlinePayValue"
FROM (
  SELECT
    com."IdOnlinePay",
    bra."BranchCompanyName"                              AS "branchCompanyName",
    CONCAT(com."Prefix", '-', com."Consecutive")         AS "cOnlinePay",
    CONCAT(ct.prefix, '-', ct."Consecutive")             AS "c",
    per."Nuip"                                           AS "nuip",
    CONCAT(per."Name", ' ', per."SurName")               AS "pName",
    nm."ResponseDateTime"                                AS "ResponseDateTime",   -- NEEDS-HUMAN: NequiMessage (Neyron_Nequi_DB)
    to_char(nm."ResponseDateTime", 'YYYY-MM-DD HH12:MI AM') AS "fhpay",           -- NEEDS-HUMAN
    nm."ResponseDateTime"::date                          AS "Date",               -- NEEDS-HUMAN: feeds WHERE2
    tn.term                                              AS "term",               -- NEEDS-HUMAN: Neyron_Nequi_DB.dbo.Term
    CASE WHEN nm."JSONMessage" IS NULL OR btrim(nm."JSONMessage") = '' THEN NULL
         ELSE jsonb_extract_path_text(nm."JSONMessage"::jsonb, 'RequestMessage', 'RequestBody', 'any', 'unregisteredPaymentRQ', 'phoneNumber') END
                                                         AS "nequiPhoneNumber",   -- NEEDS-HUMAN: JSONMessage from NequiMessage
    com."OnlinePayValue"                                 AS "onlinePayValue",
    (
      -- STRING_AGG over OPENJSON(JSONPayLoad) WITH (Name '$.Descripction') -- JSONPayLoad IS local (OnlinePay)
      SELECT string_agg(jsonb_extract_path_text(el.elem, 'Descripction'), ', ')
      FROM jsonb_array_elements(
        CASE jsonb_typeof((NULLIF(btrim(COALESCE(com."JSONPayLoad", '')), ''))::jsonb)
          WHEN 'array'  THEN (NULLIF(btrim(COALESCE(com."JSONPayLoad", '')), ''))::jsonb
          WHEN 'object' THEN jsonb_build_array((NULLIF(btrim(COALESCE(com."JSONPayLoad", '')), ''))::jsonb)
          ELSE '[]'::jsonb END
      ) AS el(elem)
    )                                                    AS "mergedValues"
  FROM (
    SELECT * FROM "OnlinePay" WHERE "OnlinePay"."idThirdPartyApplication" = 4
  ) com
  -- NEEDS-HUMAN: NequiMessage is in Neyron_Nequi_DB (separate DB, absent from IspDb DDL); identifier casing provisional.
  INNER JOIN "NequiMessage" nm ON nm."idonlinepay" = com."IdOnlinePay"
  INNER JOIN "Contract"     ct  ON ct."IdContract"     = com."IdContract"
  INNER JOIN "Address"      adr ON adr."IdAddress"     = ct."IdAddressInstalation"
  INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = adr."IdNeighborhood"
  INNER JOIN "Zone"         zon ON zon."IdZone"        = nei."IdZone"
  -- NEEDS-HUMAN: Term is in Neyron_Nequi_DB (separate DB, absent from IspDb DDL); identifier casing provisional.
  INNER JOIN "Term"         tn  ON tn."IdTerm"         = nm."IdTermNequiMessageReasonResponse"
  INNER JOIN "BranchCompany" bra ON bra."IdBranchCompany" = ct."IdBranchCompany"
  INNER JOIN "Person"       per ON per."IdPerson"      = ct."IdPerson"
  {WHERE1}
) t0
{WHERE2}
ORDER BY t0."ResponseDateTime", t0."IdOnlinePay"
