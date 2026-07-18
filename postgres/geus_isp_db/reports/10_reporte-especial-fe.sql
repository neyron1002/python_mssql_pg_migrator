-- Report: 10
-- Title: Reporte Especial FE
-- TableName: Invoice
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=10)
-- Notes: Multi #temp batch -> single WITH (C/PE/PP CTEs). Address parsed by CHARINDEX->POSITION nesting. JSON_VALUE->jsonb #>>. IIF->CASE. DATEFROMPARTS(YEAR/MONTH/DAY(CreateDate))->CreateDate::date; FORMAT(.,'d') es-CO short date approximated as to_char('FMDD/MM/YYYY'). Stratum test eTerm>3 guarded with numeric-regex cast. WHERE2 'Date' exposed by inner T0.
-- JsonParameters: {   "Column": [    {     "Name": "iPrefix",     "Title": "Prefijo",     "Type": "System.String",     "Format": ""    },    {     "Name": "iConsecutive",     "Title": "Factura",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "fDate",     "Title": "Fecha",     "Type": "System.String",     "Format": ""    },    {     "Name": "ContractConsecutive",     "Title": "USRegistro",     "Type": "System.String",     "Format": ""    },    {     "Name": "businessName",     "Title": "RazonSocial",     "Type": "System.String",     "Format": ""    },    {     "Name": "name",     "Title": "USNombres",     "Type": "System.String",     "Format": ""    },    {     "Name": "surname",     "Title": "USApellidos",     "Type": "System.String",     "Format": ""    },    {     "Name": "nuip",     "Title": "USIdentificacion",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "phoneNumber",     "Title": "Telefono",     "Type": "System.String",     "Format": ""    },    {     "Name": "email",     "Title": "Email",     "Type": "System.String",     "Format": ""    },    {     "Name": "title",     "Title": "ZONombre",     "Type": "System.String",     "Format": ""    },    {     "Name": "neighborhoodName",     "Title": "BANombre",     "Type": "System.String",     "Format": ""    },    {     "Name": "address",     "Title": "USDireccion",     "Type": "System.String",     "Format": ""    },    {     "Name": "eTerm",     "Title": "ESNombre",     "Type": "System.String",     "Format": ""    },    {     "Name": "descripction",     "Title": "CSNombre",     "Type": "System.String",     "Format": ""    },    {     "Name": "Desde",     "Title": "Desde",     "Type": "System.String",     "Format": ""    },       {     "Name": "Hasta",     "Title": "Hasta",     "Type": "System.String",     "Format": ""    },        {     "Name": "totalInvoiceDetail",     "Title": "Mantenimie",     "Type": "System.Decimal",     "Format": ""    },        {     "Name": "iva",     "Title": "Iva",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "usContrato",     "Title": "USContrato",     "Type": "System.String",     "Format": ""    },    {     "Name": "itemName",     "Title": "Item_facturado",     "Type": "System.String",     "Format": ""    },    {     "Name": "plService",     "Title": "Plan_de_servicio",     "Type": "System.String",     "Format": ""    }       ],   "Filter": {    "Geographic":true,    "CorporateLocation":false,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
WITH "C" AS (  -- was #C
  SELECT
    c."IdContract",
    c.prefix,
    c."Consecutive",
    UPPER(CONCAT(c.prefix, '-', c."Consecutive")) AS "ContractConsecutive",
    p."IdPerson",
    p."TypePerson",
    p."BusinessName",
    p."Nuip" AS "Nuip",
    p."Name",
    p."SurName",
    zon."Title",
    cit."City"          AS "CityName",
    nei."Neighborhood"  AS "NeighborhoodName",
    a."AddressName"     AS "Address",
    e."Term"            AS "eTerm",
    pls."Description"
  FROM "Contract" c
  INNER JOIN "Person"  p   ON p."IdPerson"  = c."IdPerson"
  INNER JOIN "Company" com ON com."IdCompany" = c."IdCompany"
  INNER JOIN (
    -- Address split on commas; AddressName = part after 4th comma. CHARINDEX emulated with POSITION.
    SELECT t4.*,
      btrim(substring(t4."Address" FROM t4."PNeighborhoodName" + 1)) AS "AddressName"
    FROM (
      SELECT t3.*,
        COALESCE(NULLIF(POSITION(',' IN substring(t3."Address" FROM t3."PCityName" + 1)), 0) + t3."PCityName", 0) AS "PNeighborhoodName"
      FROM (
        SELECT t2.*,
          COALESCE(NULLIF(POSITION(',' IN substring(t2."Address" FROM t2."PStateName" + 1)), 0) + t2."PStateName", 0) AS "PCityName"
        FROM (
          SELECT t1.*,
            COALESCE(NULLIF(POSITION(',' IN substring(t1."Address" FROM t1."PCountryName" + 1)), 0) + t1."PCountryName", 0) AS "PStateName"
          FROM (
            SELECT adr.*,
              POSITION(',' IN adr."Address") AS "PCountryName"
            FROM "Address" adr
          ) t1
        ) t2
      ) t3
    ) t4
  ) a ON a."IdAddress" = c."IdAddressFacturation"
  INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = a."IdNeighborhood"
  LEFT  JOIN "Zone"    zon ON zon."IdZone"    = nei."IdZone"
  INNER JOIN "City"    cit ON cit."IdCity"    = nei."IdCity"
  INNER JOIN "State"   sta ON sta."IdState"   = cit."IdState"
  INNER JOIN "Country" cou ON cou."IdCountry" = sta."IdCountry"
  INNER JOIN "PlanService" pls ON pls."IdPlanService" = c."IdPlanService"
  LEFT  JOIN "Terms"   e   ON e."IdTerms"     = a."IdTermSocioeconomic"
  {WHERE1}
),
"PE" AS (  -- #PE latest enabled email per person
  SELECT * FROM "PersonEmail"
  WHERE "IdPersonEmail" IN (
    SELECT max(pe2."IdPersonEmail")
    FROM "PersonEmail" pe2
    INNER JOIN "Person" per2 ON per2."IdPerson" = pe2."IdPerson"
    WHERE pe2."Enable" = true
    GROUP BY pe2."IdPerson"
  )
),
"PP" AS (  -- #PP latest enabled phone per person, restricted to #C
  SELECT * FROM "PersonPhoneNumber"
  WHERE "IdPhoneNumber" IN (
    SELECT max(ppn."IdPhoneNumber")
    FROM "PersonPhoneNumber" ppn
    INNER JOIN "C" cc2 ON cc2."IdPerson" = ppn."IdPerson"
    WHERE ppn."Enable" = true
    GROUP BY ppn."IdPerson"
  )
)
SELECT
  t0."iPrefix"::text               AS "iPrefix",
  t0."iConsecutive"::bigint        AS "iConsecutive",
  t0."fDate"::text                 AS "fDate",
  t0."ContractConsecutive"::text   AS "ContractConsecutive",
  t0."businessName"::text          AS "businessName",
  t0."name"::text                  AS "name",
  t0."surname"::text               AS "surname",
  t0."nuip"::bigint                AS "nuip",
  t0."phoneNumber"::text           AS "phoneNumber",
  t0."email"::text                 AS "email",
  t0."title"::text                 AS "title",
  t0."neighborhoodName"::text      AS "neighborhoodName",
  t0."address"::text               AS "address",
  t0."eTerm"::text                 AS "eTerm",
  t0."descripction"::text          AS "descripction",
  t0."Desde"::text                 AS "Desde",
  t0."Hasta"::text                 AS "Hasta",
  t0."totalInvoiceDetail"::numeric AS "totalInvoiceDetail",
  t0."iva"::numeric                AS "iva",
  t0."usContrato"::text            AS "usContrato",
  t0."itemName"::text              AS "itemName",
  t0."plService"::text             AS "plService"
FROM (
  SELECT
    com."Prefix"                                          AS "iPrefix",
    com."Consecutive"                                     AS "iConsecutive",
    CONCAT('.', to_char(com."CreateDate", 'FMDD/MM/YYYY')) AS "fDate",
    com."CreateDate"::date                               AS "Date",
    cc."ContractConsecutive",
    cc."BusinessName"      AS "businessName",
    cc."Name"             AS "name",
    cc."SurName"          AS "surname",
    cc."Nuip"            AS "nuip",
    phone."PhoneNumber"  AS "phoneNumber",
    email."Email"        AS "email",
    cc."Title"           AS "title",
    cc."NeighborhoodName" AS "neighborhoodName",
    cc."Address"         AS "address",
    cc."eTerm"           AS "eTerm",
    COALESCE(
      CASE WHEN it."JsonAccountingProductParameters" IS NULL OR btrim(it."JsonAccountingProductParameters") = '' THEN NULL
           ELSE jsonb_extract_path_text(it."JsonAccountingProductParameters"::jsonb, 'description') END,
      it."ItemName"
    )                    AS "descripction",
    idet."TotalInvoiceDetail" AS "totalInvoiceDetail",
    ''                   AS "Desde",
    ''                   AS "Hasta",
    CASE WHEN (CASE WHEN cc."eTerm" ~ '^[0-9]+$' THEN cc."eTerm"::int ELSE NULL END) > 3
              OR cc."TypePerson" = 2
              OR gs."idTermGenericService" = 42
              OR gs."idTermGenericService" IS NULL
         THEN ROUND(((idet."TotalInvoiceDetail" / 1.19) * 0.19), 2)
         ELSE 0 END      AS "iva",
    ''                   AS "usContrato",
    it."ItemName"        AS "itemName",
    cc."Description"     AS "plService"
  FROM "Invoice" com
  INNER JOIN "C" cc           ON cc."IdContract"   = com."IdContract"
  INNER JOIN "InvoiceDetail" idet ON idet."IdInvoice" = com."IdInvoice" AND idet."TotalInvoiceDetail" > 0
  INNER JOIN "Item" it        ON it."idItem"       = idet."IdItem"
  LEFT  JOIN "GenericService" gs ON gs."idItem"    = it."idItem"
  LEFT  JOIN "PP" phone       ON phone."IdPerson"  = cc."IdPerson"
  LEFT  JOIN "PE" email       ON email."IdPerson"  = cc."IdPerson"
) t0
{WHERE2}
ORDER BY t0."Date"
