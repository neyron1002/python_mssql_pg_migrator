-- Report: 15
-- Title: Recaudo Detallado Incluye Notas Credito
-- TableName: Voucher
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=15)
-- NeedsHuman: #DIC/#DICF read FROM Neyron_DI_DB.dbo.DigitalInvoice (separate DB, absent from IspDb DDL); feeds FE columns dip/dic/tdi via LEFT JOIN. Whole recaudo core is translated; DigitalInvoice must be provisioned (migrate/postgres_fdw) to run end to end.
-- Notes: Multi #temp batch -> single WITH. VoucherPaymentMethods PIVOT([Efectivo],[Online],[Otros])->SUM FILTER (method 62/143/else) per voucher. Address split as report 10. Local core (V,qtyVD,VDF,dContract,final 15-join SELECT) validated GREEN with empty DigitalInvoice stubs: all 27 columns match. Compact length ~6533 > varchar(6000): consolidation must ALTER Report.Query width. 2x WHERE1 / 2x WHERE2 preserved.
-- JsonParameters: {   "Column": [    {     "Name": "prefix",     "Title": "RC Prefijo",     "Type": "System.String",     "Format": ""    },    {     "Name": "consecutive",     "Title": "RC Consecutivo",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "vStatus",     "Title": "Estado",     "Type": "System.String",     "Format": ""    },    {     "Name": "vDocument",     "Title": "Documento",     "Type": "System.String",     "Format": ""    },    {     "Name": "pDate",     "Title": "Fecha Pago",     "Type": "System.DateTime",     "Format": ""    },    {     "Name": "dateA",     "Title": "Fecha Ingreso",     "Type": "System.String",     "Format": ""    },    {     "Name": "dateF",     "Title": "Fecha Hora Ingreso",     "Type": "System.String",     "Format": ""    },    {     "Name": "nuip",     "Title": "NUIP",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "name",     "Title": "Nombres",     "Type": "System.String",     "Format": ""    },    {     "Name": "surname",     "Title": "Apellidos",     "Type": "System.String",     "Format": ""    },    {     "Name": "city",     "Title": "Ciudad",     "Type": "System.String",     "Format": ""    },    {     "Name": "title",     "Title": "Zona",     "Type": "System.String",     "Format": ""    },    {     "Name": "neighborhood",     "Title": "Barrio",     "Type": "System.String",     "Format": ""    },    {     "Name": "address",     "Title": "Direccion",     "Type": "System.String",     "Format": ""    },    {     "Name": "e",     "Title": "Estrato",     "Type": "System.String",     "Format": ""    },    {     "Name": "officeName",     "Title": "Oficina",     "Type": "System.String",     "Format": ""    },    {     "Name": "casherName",     "Title": "Cajero",     "Type": "System.String",     "Format": ""    },       {     "Name": "ef",     "Title": "Efectivo",     "Type": "System.Decimal",     "Format": ""    },        {     "Name": "o",     "Title": "Online",     "Type": "System.Decimal",     "Format": ""    },        {     "Name": "ot",     "Title": "Otros",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "Service",     "Title": "Servicio",     "Type": "System.String",     "Format": ""    },    {     "Name": "itemName",     "Title": "Detalle",     "Type": "System.String",     "Format": ""    },    {     "Name": "descripction",     "Title": "Concepto",     "Type": "System.String",     "Format": ""    },    {     "Name": "totalPayDetail",     "Title": "Total Detalle Factura",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "dip",     "Title": "FE Prefijo",     "Type": "System.String",     "Format": ""    },    {     "Name": "dic",     "Title": "FE Consecutivo",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "tdi",     "Title": "FE Valor",     "Type": "System.Decimal",     "Format": ""    }       ],   "Filter": {    "Geographic":false,    "CorporateLocation":false,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
-- NEEDS-HUMAN: the #DIC/#DICF pipeline reads FROM Neyron_DI_DB.dbo.DigitalInvoice,
-- a database that is NOT part of the 57-table IspDb PG DDL. That feeds the FE
-- columns dip/dic/tdi (via a LEFT JOIN, COALESCEd to 'NA'/0). The whole Voucher
-- "recaudo" core (CTEs V, qtyVD, VDF incl. the VoucherPaymentMethods PIVOT->FILTER,
-- dContract incl. the address split, and the final SELECT) is fully translated and
-- was validated in isolation with empty DigitalInvoice stubs (see status-c.md).
-- The two DigitalInvoice CTEs are kept below, flagged, referencing a bare
-- "DigitalInvoice" table that a human must provision (migrate Neyron_DI_DB or wire
-- postgres_fdw) for the report to run end to end. Both WHERE1 and both WHERE2
-- placeholders are preserved (2 each).
WITH "DIC" AS (  -- was #DIC. NEEDS-HUMAN: source table below is external (Neyron_DI_DB).
  SELECT * FROM (
    SELECT
      com."IdDigitalInvoice",
      com."IdCompany",
      com."DigitalInvoicePrefix",
      com."DigitalInvoiceConsecutive",
      (jsonb_extract_path_text(el.elem, 'IdTable'))::bigint     AS "IdTable",
      (jsonb_extract_path_text(el.elem, 'IdContract'))::bigint  AS "IdContract",
      (jsonb_extract_path_text(el.elem, 'CreateDate'))::date    AS "Date",
      jsonb_extract_path(el.elem, 'InvoiceDetailes')        AS "InvoiceDetailes"
    FROM (
      -- NEEDS-HUMAN: Neyron_DI_DB.dbo.DigitalInvoice — not in IspDb DDL.
      SELECT * FROM "DigitalInvoice" com
      {WHERE1}
      AND com."IdTermDigitalInvoiceStatus" = 145
    ) com
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(jsonb_extract_path((NULLIF(btrim(COALESCE(com."JsonPayLoad", '')), ''))::jsonb, 'DiLoad')) = 'array'
           THEN jsonb_extract_path((NULLIF(btrim(COALESCE(com."JsonPayLoad", '')), ''))::jsonb, 'DiLoad')
           ELSE '[]'::jsonb END
    ) AS el(elem)
  ) t0
  {WHERE2}
),
"DICF" AS (  -- was #DICF. NEEDS-HUMAN: derived from external DIC (double OPENJSON on InvoiceDetailes).
  SELECT
    d."IdDigitalInvoice", d."IdCompany",
    d."DigitalInvoicePrefix"     AS "DIP",
    d."DigitalInvoiceConsecutive" AS "DIC",
    d."IdTable", d."IdContract", d."Date",
    (jsonb_extract_path_text(e2.elem, 'IdInvoiceDetail'))::bigint AS "IdInvoiceDetail",
    (jsonb_extract_path_text(e2.elem, 'IdInvoice'))::bigint       AS "IdInvoice",
    (jsonb_extract_path_text(e2.elem, 'TotalPay'))::numeric        AS "TotalPay"
  FROM "DIC" d
  CROSS JOIN LATERAL jsonb_array_elements(
    CASE WHEN jsonb_typeof(d."InvoiceDetailes") = 'array' THEN d."InvoiceDetailes" ELSE '[]'::jsonb END
  ) AS e1(val)
  CROSS JOIN LATERAL jsonb_array_elements(
    CASE WHEN jsonb_typeof(e1.val) = 'array' THEN e1.val ELSE jsonb_build_array(e1.val) END
  ) AS e2(elem)
),
"V" AS (  -- was #V: Voucher rows scoped by tenant + date. WHERE1 #2 / WHERE2 #2 live here.
  SELECT com.* FROM "Voucher" AS com
  INNER JOIN (
    SELECT "IdVoucher" FROM (
      SELECT com."IdVoucher", com."Date"::date AS "Date"
      FROM "Voucher" AS com
      {WHERE1}
    ) t0
    {WHERE2}
  ) t1 ON t1."IdVoucher" = com."IdVoucher"
),
"qtyVD" AS (  -- was #qtyVD
  SELECT v."IdVoucher",
    COUNT(vd."IdVoucherDetail") AS "QTYVoucherDetail",
    SUM(vd."PayValue")          AS "TPayValue"
  FROM "V" v
  INNER JOIN "VoucherDetail" vd ON vd."IdVoucher" = v."IdVoucher"
  GROUP BY v."IdVoucher"
),
"VDF" AS (  -- was #VDF. PIVOT(SUM(PayValue) FOR tMethodPayment IN([Efectivo],[Online],[Otros]))
            -- -> conditional aggregation: Efectivo=method 62, Online=method 143, Otros=all others.
  SELECT
    vd."IdVoucher",
    vd."IdVoucherDetail",
    vd."PayValue",
    q."TPayValue",
    CASE WHEN q."TPayValue" = 0 THEN 0 ELSE (vd."PayValue"::numeric / q."TPayValue"::numeric) END AS "AA",
    t2."Efectivo" * CASE WHEN q."TPayValue" = 0 THEN 0 ELSE (vd."PayValue"::numeric / q."TPayValue"::numeric) END AS "Efectivo",
    t2."Online"   * CASE WHEN q."TPayValue" = 0 THEN 0 ELSE (vd."PayValue"::numeric / q."TPayValue"::numeric) END AS "Online",
    t2."Otros"    * CASE WHEN q."TPayValue" = 0 THEN 0 ELSE (vd."PayValue"::numeric / q."TPayValue"::numeric) END AS "Otros"
  FROM (
    SELECT
      vpm."IdVoucher",
      COALESCE(SUM(vpm."PayValue") FILTER (WHERE vpm."IdTermTypePaymentMethod" = 62), 0)          AS "Efectivo",
      COALESCE(SUM(vpm."PayValue") FILTER (WHERE vpm."IdTermTypePaymentMethod" = 143), 0)         AS "Online",
      COALESCE(SUM(vpm."PayValue") FILTER (WHERE vpm."IdTermTypePaymentMethod" NOT IN (62, 143)), 0) AS "Otros"
    FROM "V" v
    INNER JOIN "VoucherPaymentMethods" vpm ON vpm."IdVoucher" = v."IdVoucher"
    GROUP BY vpm."IdVoucher"
  ) t2
  INNER JOIN "qtyVD" q        ON q."IdVoucher"  = t2."IdVoucher"
  INNER JOIN "VoucherDetail" vd ON vd."IdVoucher" = t2."IdVoucher"
),
"dContract" AS (  -- was #dContract: contract/person/address for vouchers in #V
  SELECT
    c."IdContract",
    UPPER(CONCAT(c.prefix, '-', c."Consecutive")) AS "ContractConsecutive",
    p."Nuip" AS "Nuip",
    p."Name",
    p."SurName",
    cit."City"         AS "city",
    nei."Neighborhood" AS "neighborhood",
    zon."Title",
    a."AddressName"    AS "Address",
    COALESCE(ter."Term", '') AS "e"
  FROM "Contract" c
  INNER JOIN "Person"  p   ON p."IdPerson"  = c."IdPerson"
  INNER JOIN "Company" com ON com."IdCompany" = c."IdCompany"
  INNER JOIN (
    -- Address split on commas; take part after the 4th comma. Same pattern as report 10.
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
            SELECT adr.*, POSITION(',' IN adr."Address") AS "PCountryName"
            FROM "Address" adr
          ) t1
        ) t2
      ) t3
    ) t4
  ) a ON a."IdAddress" = c."IdAddressFacturation"
  INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = a."IdNeighborhood"
  INNER JOIN "City"  cit ON cit."IdCity"  = nei."IdCity"
  INNER JOIN "Zone"  zon ON zon."IdZone"  = nei."IdZone"
  LEFT  JOIN "Terms" ter ON ter."IdTerms" = a."IdTermSocioeconomic"
  WHERE c."IdContract" IN (SELECT v."IdContract" FROM "V" v)
)
SELECT
  com.prefix::text                                AS "prefix",
  com."Consecutive"::bigint                       AS "consecutive",
  vs."Term"::text                                 AS "vStatus",
  vss."Term"::text                                AS "vDocument",
  com."PayDate"::timestamp                        AS "pDate",
  to_char(com."Date", 'YYYY-MM-DD')::text         AS "dateA",
  to_char(com."Date", 'YYYY-MM-DD HH12:MI AM')::text AS "dateF",
  ct."Nuip"::bigint                               AS "nuip",
  ct."Name"::text                                 AS "name",
  ct."SurName"::text                              AS "surname",
  ct."city"::text                                 AS "city",
  ct."Title"::text                                AS "title",
  ct."neighborhood"::text                         AS "neighborhood",
  ct."Address"::text                              AS "address",
  ct."e"::text                                    AS "e",
  ofi."OfficeName"::text                          AS "officeName",
  CONCAT(per."Name", ' ', per."SurName")::text    AS "casherName",
  COALESCE(vdf."Efectivo", 0)::numeric            AS "ef",
  COALESCE(vdf."Online", 0)::numeric              AS "o",
  COALESCE(vdf."Otros", 0)::numeric               AS "ot",
  svc."Term"::text                                AS "Service",
  it."ItemName"::text                             AS "itemName",
  idet."Descripction"::text                       AS "descripction",
  vd."PayValue"::numeric                          AS "totalPayDetail",
  COALESCE(dicf."DIP", 'NA')::text                AS "dip",   -- NEEDS-HUMAN (external DigitalInvoice)
  COALESCE(dicf."DIC", 0)::bigint                 AS "dic",   -- NEEDS-HUMAN
  COALESCE(dicf."TotalPay", 0)::numeric           AS "tdi"    -- NEEDS-HUMAN
FROM "V" com
INNER JOIN "Terms" vs           ON vs."IdTerms"          = com."IdTermVoucherStatus"
INNER JOIN "Terms" vss          ON vss."IdTerms"         = com."IdTermDocumentType"
INNER JOIN "VoucherDetail" vd   ON vd."IdVoucher"        = com."IdVoucher"
INNER JOIN "InvoiceDetail" idet ON idet."IdInvoiceDetail" = vd."IdInvoiceDetail"
LEFT  JOIN "VDF" vdf            ON vdf."IdVoucherDetail"  = vd."IdVoucherDetail"
INNER JOIN "Item" it            ON it."idItem"           = idet."IdItem"
LEFT  JOIN "GenericService" gs  ON gs."idItem"           = idet."IdItem"
LEFT  JOIN "Terms" svc          ON svc."IdTerms"         = gs."idTermGenericService"
LEFT  JOIN "DICF" dicf          ON dicf."IdInvoiceDetail" = vd."IdInvoiceDetail" AND com."IdVoucher" = dicf."IdTable"
INNER JOIN "dContract" ct       ON ct."IdContract"       = com."IdContract"
INNER JOIN "CashRegisterLog" crl ON crl."IdCashRegisterLog" = com."IdCashRegisterLog"
INNER JOIN "CashRegister" cr    ON cr."IdCashRegister"   = crl."IdCashRegister"
INNER JOIN "Office" ofi         ON ofi."IdOffice"        = cr."IdOffice"
INNER JOIN "Employee" emp       ON emp."IdEmployee"      = crl."IdEmployee"
INNER JOIN "Person" per         ON per."IdPerson"        = emp."IdPerson"
ORDER BY com."Date", com.prefix, com."Consecutive"
