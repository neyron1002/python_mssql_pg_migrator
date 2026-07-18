-- Report: 16
-- Title: Reporte BANCOLOMBIA
-- TableName: Invoie
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=16)
-- Notes: PIVOT(SUM(Debt) FOR IdTermGenericService IN([42],[43]))->SUM(Debt) FILTER(WHERE idTermGenericService=42/43) grouped by IdContract. IIF->CASE. com.Pay=0->false. No WHERE2 (where2Count=0). InvoiceDetail."IdItem" vs GenericService."idItem" case differs per DDL.
-- JsonParameters: {   "Column": [    {     "Name": "IDCONTRATO",     "Title": "IDCONTRATO",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "TV",     "Title": "TV",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "INTERNET",     "Title": "INTERNET",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "CODIGO_CONTRATO",     "Title": "CODIGO_CONTRATO",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "ESTADO_CONTRATO",     "Title": "ESTADO_CONTRATO",     "Type": "System.String",     "Format": ""    },    {     "Name": "CC_NIT",     "Title": "CC_NIT",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "RAZON_SOCIAL",     "Title": "RAZON_SOCIAL",     "Type": "System.String",     "Format": ""    },    {     "Name": "NOMBRES",     "Title": "NOMBRES",     "Type": "System.String",     "Format": ""    },    {     "Name": "APELLIDOS",     "Title": "APELLIDOS",     "Type": "System.String",     "Format": ""    },    {     "Name": "ZONA",     "Title": "ZONA",     "Type": "System.String",     "Format": ""    }     ],   "Filter": {    "Geographic":false,    "CorporateLocation":false,    "Employee":false,    "Date": false,    "DateRange": false,    "DateTimeRange": false,    "Debt": false   }  }
---
SELECT
  con."IdContract"::bigint                                                   AS "IDCONTRATO",
  COALESCE(pp."42", 0)::numeric                                              AS "TV",
  COALESCE(pp."43", 0)::numeric                                              AS "INTERNET",
  con."Consecutive"::bigint                                                  AS "CODIGO_CONTRATO",
  (CASE WHEN con."IdTermContractStatus" = 5 THEN 'ACTIVO' ELSE 'INACTIVO' END)::text AS "ESTADO_CONTRATO",
  per."Nuip"::bigint                                                         AS "CC_NIT",
  COALESCE(per."BusinessName", '')::text                                     AS "RAZON_SOCIAL",
  per."Name"::text                                                           AS "NOMBRES",
  per."SurName"::text                                                        AS "APELLIDOS",
  zon."Title"::text                                                          AS "ZONA"
FROM (
  -- PIVOT (SUM(Debt) FOR IdTermGenericService IN ([42],[43])) rewritten as conditional aggregation
  SELECT
    p."IdContract",
    SUM(p."Debt") FILTER (WHERE p."idTermGenericService" = 42) AS "42",
    SUM(p."Debt") FILTER (WHERE p."idTermGenericService" = 43) AS "43"
  FROM (
    SELECT
      com."IdContract",
      gs."idTermGenericService",
      SUM(idet."TotalInvoiceDetail") - SUM(idet."TotalPay") AS "Debt"
    FROM "Invoice" AS com
    INNER JOIN "InvoiceDetail" idet ON idet."IdInvoice" = com."IdInvoice"
    INNER JOIN "GenericService" gs  ON gs."idItem"     = idet."IdItem"
    {WHERE1}
    and com."Pay" = false
    GROUP BY com."IdContract", gs."idTermGenericService"
  ) p
  GROUP BY p."IdContract"
) pp
INNER JOIN "Contract"     con ON con."IdContract"     = pp."IdContract"
INNER JOIN "Person"       per ON per."IdPerson"       = con."IdPerson"
INNER JOIN "Address"      adr ON adr."IdAddress"      = con."IdAddressInstalation"
INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = adr."IdNeighborhood"
INNER JOIN "Zone"         zon ON zon."IdZone"         = nei."IdZone"
ORDER BY zon."Title", con."Consecutive"
