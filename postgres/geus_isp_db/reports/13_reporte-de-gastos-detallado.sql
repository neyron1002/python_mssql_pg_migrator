-- Report: 13
-- Title: Reporte de Gastos Detallado
-- TableName: Expense
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=13)
-- Notes: STRING_AGG(OPENJSON(JSON_QUERY(JsonParameters,'$.FamilyTree')) WITH(Name '$.idTypeCompanyName'))->string_agg over jsonb_array_elements(#>'{FamilyTree}'). FORMAT(.,'yyyy-MM-dd hh:mm tt')->to_char('YYYY-MM-DD HH12:MI AM'). BranchCompany 'com' wrapped to expose "IdCompany" (DDL column is "idCompany"). WHERE2 'Date'=CreateDateTime::date in T0.
-- JsonParameters: {   "Column": [    {     "Name": "idExpense",     "Title": "Cod",     "Type": "System.Int32",     "Format": ""    },{     "Name": "branchCompanyName",     "Title": "Sucursal",     "Type": "System.String",     "Format": ""    },{     "Name": "officeName",     "Title": "Oficina",     "Type": "System.String",     "Format": ""    },{     "Name": "term",     "Title": "Estado",     "Type": "System.String",     "Format": ""    },{     "Name": "a",     "Title": "Categoria",     "Type": "System.String",     "Format": ""    },{     "Name": "subject",     "Title": "Asunto",     "Type": "System.String",     "Format": ""    },    {     "Name": "description",     "Title": "Descripcion",     "Type": "System.String",     "Format": ""    },    {     "Name": "expenseValue",     "Title": "Valor Gasto",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "createDateTime",     "Title": "Fecha y Hora Creacion",     "Type": "System.String",     "Format": ""    },{     "Name": "doneDateTime",     "Title": "Fecha y Hora Aprobacion",     "Type": "System.String",     "Format": ""    }   ],   "Filter": {    "Geographic":false,    "CorporateLocation":true,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
SELECT
  t0."IdExpense"::int                                          AS "idExpense",
  t0."BranchCompanyName"::text                                 AS "branchCompanyName",
  t0."OfficeName"::text                                        AS "officeName",
  t0."Term"::text                                              AS "term",
  (
    -- STRING_AGG over OPENJSON(JSON_QUERY(JsonParameters,'$.FamilyTree')) WITH (Name '$.idTypeCompanyName')
    SELECT string_agg(jsonb_extract_path_text(ft.elem, 'idTypeCompanyName'), ', ')
    FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(jsonb_extract_path((NULLIF(btrim(COALESCE(t0."JsonParameters", '')), ''))::jsonb, 'FamilyTree')) = 'array'
           THEN jsonb_extract_path((NULLIF(btrim(COALESCE(t0."JsonParameters", '')), ''))::jsonb, 'FamilyTree')
           ELSE '[]'::jsonb END
    ) AS ft(elem)
  )::text                                                      AS "a",
  t0."Subject"::text                                           AS "subject",
  t0."Description"::text                                       AS "description",
  t0."ExpenseValue"::numeric                                   AS "expenseValue",
  to_char(t0."CreateDateTime", 'YYYY-MM-DD HH12:MI AM')::text  AS "createDateTime",
  to_char(t0."DoneDateTime",   'YYYY-MM-DD HH12:MI AM')::text  AS "doneDateTime"
FROM (
  SELECT
    exp.*,
    exp."CreateDateTime"::date AS "Date",
    ter."Term",
    bra."BranchCompanyName",
    ofi."OfficeName"
  FROM "Expense" exp
  INNER JOIN "CashRegisterLog" crl ON crl."IdCashRegisterLog" = exp."IdCashRegisterLog"
  INNER JOIN "CashRegister"    cas ON cas."IdCashRegister"     = crl."IdCashRegister"
  INNER JOIN "Office"          ofi ON ofi."IdOffice"           = cas."IdOffice"
  -- BranchCompany "com" wrapped so the engine's WHERE1 (com."IdCompany") resolves:
  -- the physical column is "idCompany" (lowercase) in the DDL.
  INNER JOIN (SELECT "IdBranchCompany", "idCompany" AS "IdCompany" FROM "BranchCompany") com
          ON com."IdBranchCompany" = ofi."IdBranchCompany"
  INNER JOIN "BranchCompany"   bra ON bra."IdBranchCompany"    = ofi."IdBranchCompany"
  INNER JOIN "Terms"           ter ON ter."IdTerms"            = exp."IdTermStatusExpense"
  {WHERE1}
) t0
{WHERE2}
ORDER BY t0."CreateDateTime"
