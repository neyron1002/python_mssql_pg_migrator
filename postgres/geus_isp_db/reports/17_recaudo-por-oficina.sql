-- Report: 17
-- Title: Recaudo por Oficina
-- TableName: Voucher
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=17)
-- Notes: T-SQL original era un lote `SELECT * INTO #V FROM (...) T0 {WHERE2} ... SELECT
--   ... FROM #V ... DROP TABLE #V` (dos sentencias con estado intermedio). Reestructurado
--   a una sola sentencia con dos CTEs encadenadas ("T0" = subconsulta que declaraba
--   {WHERE1}; "V" = equivalente de #V, expone {WHERE2} contra la columna "Date" heredada
--   de com.* / Voucher."Date") seguido del SELECT final -- ver LEY CRITICA (c) de
--   CONVENTIONS.md. El SELECT final solo proyecta las columnas declaradas en
--   JsonParameters.Column[] (title/neighborhood/officeName/term/total/quantity);
--   Zone.IdZone/Neighborhood.IdNeighborhood/Office.IdOffice del T-SQL original se
--   mantienen solo en el GROUP BY (no en el SELECT), ya que no estan en Column[].
-- JsonParameters: {   "Column": [    {     "Name": "title",     "Title": "Zona",     "Type": "System.String",     "Format": ""    },    {     "Name": "neighborhood",     "Title": "Barrio",     "Type": "System.String",     "Format": ""    },    {     "Name": "officeName",     "Title": "Oficina",     "Type": "System.String",     "Format": ""    },    {     "Name": "term",     "Title": "Medio de Pago",     "Type": "System.String",     "Format": ""    },    {     "Name": "total",     "Title": "Contrato",     "Type": "System.Decimal",     "Format": "Currency"    },    {     "Name": "quantity",     "Title": "Cantidad",     "Type": "System.Int32",     "Format": ""    }   ],   "Filter": {    "Geographic":true,    "CorporateLocation":true,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
with "T0" as (
  select com.* from "Voucher" as com
  inner join "Contract" on "Contract"."IdContract" = com."IdContract"
  inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
  inner join "Neighborhood" as nei on nei."IdNeighborhood" = "Address"."IdNeighborhood"
  inner join "Zone" as zon on zon."IdZone" = nei."IdZone"
  inner join "City" as cit on cit."IdCity" = nei."IdCity"
  inner join "State" as sta on sta."IdState" = cit."IdState"
  inner join "Country" as cou on cou."IdCountry" = sta."IdCountry"
  inner join "CashRegisterLog" on "CashRegisterLog"."IdCashRegisterLog" = com."IdCashRegisterLog"
  inner join "CashRegister" on "CashRegister"."IdCashRegister" = "CashRegisterLog"."IdCashRegister"
  inner join "Office" as ofi on ofi."IdOffice" = "CashRegister"."IdOffice"
  inner join "BranchCompany" as bra on bra."IdBranchCompany" = ofi."IdBranchCompany"
  {WHERE1}
  and com."IdTermDocumentType" = 38
),
"V" as (
  select * from "T0"
  {WHERE2}
)
select
  zon."Title"::text as "title",
  nei."Neighborhood"::text as "neighborhood",
  ofi."OfficeName"::text as "officeName",
  ter."Term"::text as "term",
  (sum(vpm."PayValue"))::numeric as "total",
  (count(com."IdVoucher"))::int as "quantity"
from "V" as com
inner join "VoucherPaymentMethods" as vpm on vpm."IdVoucher" = com."IdVoucher"
inner join "Contract" on "Contract"."IdContract" = com."IdContract"
inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
inner join "Neighborhood" as nei on nei."IdNeighborhood" = "Address"."IdNeighborhood"
inner join "Zone" as zon on zon."IdZone" = nei."IdZone"
inner join "CashRegisterLog" on "CashRegisterLog"."IdCashRegisterLog" = com."IdCashRegisterLog"
inner join "CashRegister" on "CashRegister"."IdCashRegister" = "CashRegisterLog"."IdCashRegister"
inner join "Office" as ofi on ofi."IdOffice" = "CashRegister"."IdOffice"
inner join "Terms" as ter on ter."IdTerms" = vpm."IdTermTypePaymentMethod"
group by zon."IdZone", zon."Title", nei."IdNeighborhood", nei."Neighborhood", ofi."IdOffice", ofi."OfficeName", ter."Term"
order by zon."Title", nei."Neighborhood", ofi."OfficeName", ter."Term"
