-- Report: 19
-- Title: Recaudo por Oficina, Cajero y Servicio
-- TableName: Voucher
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=19)
-- Notes: Mismo patron de reestructuracion a CTE que los reportes 17/18. Agrega por
--   VoucherDetail/InvoiceDetail en vez de VoucherPaymentMethods (agregacion sobre
--   "servicio" via GenericService/Terms, LEFT JOIN preservado porque un InvoiceDetail
--   puede referenciar un Item sin GenericService asociado). "Person.Surname" (T-SQL)
--   -> columna real "SurName". Solo se proyectan las columnas de
--   JsonParameters.Column[] (officeName/employeeName/service/total/quantity).
-- JsonParameters: {   "Column": [    {     "Name": "officeName",     "Title": "Oficina",     "Type": "System.String",     "Format": ""    },    {     "Name": "employeeName",     "Title": "Cajero",     "Type": "System.String",     "Format": ""    },    {     "Name": "service",     "Title": "Servicio",     "Type": "System.String",     "Format": ""    },    {     "Name": "total",     "Title": "Contrato",     "Type": "System.Decimal",     "Format": "Currency"    },    {     "Name": "quantity",     "Title": "Cantidad",     "Type": "System.Int32",     "Format": ""    }   ],   "Filter": {    "Geographic":true,    "CorporateLocation":true,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
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
  sterms."Term"::text as "service",
  (sum(vd."PayValue"))::numeric as "total",
  (count(com."IdVoucher"))::int as "quantity"
from "V" as com
inner join "VoucherDetail" as vd on vd."IdVoucher" = com."IdVoucher"
inner join "InvoiceDetail" on "InvoiceDetail"."IdInvoiceDetail" = vd."IdInvoiceDetail"
left join "GenericService" on "GenericService"."idItem" = "InvoiceDetail"."IdItem"
left join "Terms" as sterms on sterms."IdTerms" = "GenericService"."idTermGenericService"
inner join "Contract" on "Contract"."IdContract" = com."IdContract"
inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
inner join "Neighborhood" on "Neighborhood"."IdNeighborhood" = "Address"."IdNeighborhood"
inner join "Zone" on "Zone"."IdZone" = "Neighborhood"."IdZone"
inner join "CashRegisterLog" on "CashRegisterLog"."IdCashRegisterLog" = com."IdCashRegisterLog"
inner join "CashRegister" on "CashRegister"."IdCashRegister" = "CashRegisterLog"."IdCashRegister"
inner join "Office" as ofi on ofi."IdOffice" = "CashRegister"."IdOffice"
inner join "Employee" on "Employee"."IdEmployee" = "CashRegisterLog"."IdEmployee"
inner join "Person" as p on p."IdPerson" = "Employee"."IdPerson"
group by ofi."IdOffice", ofi."OfficeName", "Employee"."IdEmployee", concat(p."Name", ' ', p."SurName"), sterms."Term"
order by ofi."IdOffice", ofi."OfficeName", concat(p."Name", ' ', p."SurName"), sterms."Term"
