-- Report: 20
-- Title: Recaudo por Fecha y Oficina
-- TableName: Voucher
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=20)
-- Notes: Mismo patron de reestructuracion a CTE que los reportes 17/18/19.
--   FORMAT(Date, 'yyyy-MM-dd') AS dd (T-SQL) -> to_char(com."Date", 'YYYY-MM-DD') AS "dd",
--   calculado dentro de "T0" (junto con com.*) para que sobreviva a traves de "V" y quede
--   disponible para el GROUP BY del SELECT final, igual que en el T-SQL original donde
--   "dd" viajaba como columna materializada de #V. {WHERE2} sigue resolviendo contra la
--   columna "Date" (Voucher."Date", heredada via com.* en "T0"), no contra "dd".
-- JsonParameters: {   "Column": [    {     "Name": "title",     "Title": "Zona",     "Type": "System.String",     "Format": ""    },    {     "Name": "dd",     "Title": "Fecha",     "Type": "System.String",     "Format": ""    },    {     "Name": "officeName",     "Title": "Oficina",     "Type": "System.String",     "Format": ""    },    {     "Name": "term",     "Title": "Medio de Pago",     "Type": "System.String",     "Format": ""    },    {     "Name": "total",     "Title": "Contrato",     "Type": "System.Decimal",     "Format": "Currency"    },    {     "Name": "quantity",     "Title": "Cantidad",     "Type": "System.Int32",     "Format": ""    }   ],   "Filter": {    "Geographic":true,    "CorporateLocation":true,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
with "T0" as (
  select com.*, to_char(com."Date", 'YYYY-MM-DD') as "dd"
  from "Voucher" as com
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
  com."dd"::text as "dd",
  ofi."OfficeName"::text as "officeName",
  ter."Term"::text as "term",
  (sum(vpm."PayValue"))::numeric as "total",
  (count(com."IdVoucher"))::int as "quantity"
from "V" as com
inner join "VoucherPaymentMethods" as vpm on vpm."IdVoucher" = com."IdVoucher"
inner join "Contract" on "Contract"."IdContract" = com."IdContract"
inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
inner join "Neighborhood" on "Neighborhood"."IdNeighborhood" = "Address"."IdNeighborhood"
inner join "Zone" as zon on zon."IdZone" = "Neighborhood"."IdZone"
inner join "CashRegisterLog" on "CashRegisterLog"."IdCashRegisterLog" = com."IdCashRegisterLog"
inner join "CashRegister" on "CashRegister"."IdCashRegister" = "CashRegisterLog"."IdCashRegister"
inner join "Office" as ofi on ofi."IdOffice" = "CashRegister"."IdOffice"
inner join "Terms" as ter on ter."IdTerms" = vpm."IdTermTypePaymentMethod"
group by zon."IdZone", zon."Title", com."dd", ofi."IdOffice", ofi."OfficeName", ter."Term"
order by zon."Title", ofi."OfficeName", ter."Term"
