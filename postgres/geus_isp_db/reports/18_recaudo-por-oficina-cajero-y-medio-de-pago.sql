-- Report: 18
-- Title: Recaudo por Oficina, Cajero y Medio de Pago
-- TableName: Voucher
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=18)
-- Notes: Mismo patron de reestructuracion a CTE que el reporte 17 (ver su Notes) --
--   lote T-SQL `SELECT * INTO #V ... {WHERE2} ... SELECT ... DROP TABLE #V` se vuelve
--   `WITH "T0" AS (...), "V" AS (...) SELECT ...`. "Person.Surname" (T-SQL,
--   case-insensitive) se traduce a la columna real "SurName" (ver schema-inventory.md,
--   tabla "Person"). CONCAT(Person.Name, ' ', Person.Surname) se mantiene igual (CONCAT
--   existe identico en PG, misma semantica de no propagar NULL). Los JOIN a
--   Neighborhood/Zone en el SELECT final se preservan tal cual el T-SQL original aunque
--   no se proyecten (relacion 1:1 via Address, no alteran cardinalidad); solo se
--   proyectan las columnas declaradas en JsonParameters.Column[].
-- JsonParameters: {   "Column": [    {     "Name": "officeName",     "Title": "Oficina",     "Type": "System.String",     "Format": ""    },    {     "Name": "employeeName",     "Title": "Cajero",     "Type": "System.String",     "Format": ""    },    {     "Name": "term",     "Title": "Medio de Pago",     "Type": "System.String",     "Format": ""    },    {     "Name": "tbTerm",     "Title": "Banco",     "Type": "System.String",     "Format": ""    },    {     "Name": "total",     "Title": "Contrato",     "Type": "System.Decimal",     "Format": "Currency"    },    {     "Name": "quantity",     "Title": "Cantidad",     "Type": "System.Int32",     "Format": ""    }   ],   "Filter": {    "Geographic":true,    "CorporateLocation":true,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
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
  inner join "Employee" on "Employee"."IdEmployee" = "CashRegisterLog"."IdEmployee"
  {WHERE1}
  and com."IdTermDocumentType" = 38
),
"V" as (
  select * from "T0"
  {WHERE2}
)
select
  ofi."OfficeName"::text as "officeName",
  (concat(p."Name", ' ', p."SurName"))::text as "employeeName",
  ter."Term"::text as "term",
  tb."Term"::text as "tbTerm",
  (sum(vpm."PayValue"))::numeric as "total",
  (count(com."IdVoucher"))::int as "quantity"
from "V" as com
inner join "VoucherPaymentMethods" as vpm on vpm."IdVoucher" = com."IdVoucher"
inner join "Contract" on "Contract"."IdContract" = com."IdContract"
inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
inner join "Neighborhood" on "Neighborhood"."IdNeighborhood" = "Address"."IdNeighborhood"
inner join "Zone" on "Zone"."IdZone" = "Neighborhood"."IdZone"
inner join "CashRegisterLog" on "CashRegisterLog"."IdCashRegisterLog" = com."IdCashRegisterLog"
inner join "CashRegister" on "CashRegister"."IdCashRegister" = "CashRegisterLog"."IdCashRegister"
inner join "Office" as ofi on ofi."IdOffice" = "CashRegister"."IdOffice"
inner join "Terms" as ter on ter."IdTerms" = vpm."IdTermTypePaymentMethod"
inner join "Terms" as tb on tb."IdTerms" = vpm."IdTermBank"
inner join "Employee" on "Employee"."IdEmployee" = "CashRegisterLog"."IdEmployee"
inner join "Person" as p on p."IdPerson" = "Employee"."IdPerson"
group by ofi."IdOffice", ofi."OfficeName", "Employee"."IdEmployee", concat(p."Name", ' ', p."SurName"), ter."Term", tb."Term"
order by ofi."IdOffice", ofi."OfficeName", concat(p."Name", ' ', p."SurName"), ter."Term", tb."Term"
