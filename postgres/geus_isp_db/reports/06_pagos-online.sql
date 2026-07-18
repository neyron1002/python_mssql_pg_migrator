-- Report: 6
-- Title: Pagos Online
-- TableName: Voucher
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=6)
-- Notes: T-SQL original era un lote de 3 sentencias (`SELECT ... INTO #VO`,
--   `SELECT ... INTO #VOC`, `SELECT final ...` + `DROP TABLE`), inejecutable tal
--   cual bajo el protocolo extendido de Npgsql (ver CONVENTIONS.md LEY CRITICA (c)).
--   Traducido a una unica sentencia con dos CTE encadenados ("VO" -> "VOC") que
--   replican exactamente los dos #temp originales; el ultimo SELECT del lote es el
--   SELECT final tras el WITH. {WHERE2} (DateRange, unico filtro generico de este
--   reporte) se resuelve dentro de "VO" contra "Voucher"."Date" (Voucher esta en el
--   FROM directo de esa CTE, sin necesidad de proyectarlo explicitamente -- ver
--   CONVENTIONS.md (b)). {WHERE1} se resuelve en el SELECT final contra
--   "Contract" aliased com (alias fijo del motor), que expone "IdCompany" en
--   PascalCase sin conflicto de case. Invoice.Prefix es la UNICA tabla de este
--   grupo con "Prefix" en mayuscula inicial (a diferencia de Contract/Voucher/
--   SupportTicket, que usan "prefix" minuscula) -- verificado contra
--   schema-inventory.md, no es un error de este archivo. FORMAT(...,'yyyy-MMMM-dd',
--   'es-ES') (nombre de mes en espanol) no tiene mapeo 1:1 en la tabla de
--   CONVENTIONS.md (f) (que solo cubre yyyy/MM/dd/HH/mm/ss/tt). Primer intento
--   `to_char(...,'YYYY-TMMonth-DD')` + lower() se DESCARTO tras autovalidacion:
--   `TMMonth` usa el nombre de mes segun `lc_time` DEL CLUSTER Postgres, un ajuste
--   INDEPENDIENTE de la coleccion ICU es-ES de la base -- confirmado empiricamente
--   contra pgrep_d (`show lc_time` -> `en_US.utf8` por defecto en la imagen
--   postgres:18 estandar), produciendo "2023-january-15" en vez de
--   "2023-enero-15". Se reemplazo por un array literal de los 12 nombres de mes
--   en espanol indexado por `extract(month from f)::int`
--   (`concat(extract(year from f)::text,'-', array['enero',...,'diciembre']
--   [extract(month from f)::int],'-', lpad(extract(day from f)::text,2,'0'))`),
--   determinista e independiente de la configuracion regional del servidor que
--   ejecute la query -- verificado contra 4 meses de muestra
--   (enero/mayo/septiembre/diciembre), coincide con el shape
--   "yyyy-mes_completo-dd" en minuscula que produce el FORMAT(...,'es-ES')
--   original (riesgo funcional cerrado, ya no solo documentado). El reporte
--   original NO
--   une "Country"/cou pese a `Filter.Geographic=true` (solo nei/zon/cit/sta) --
--   preservado tal cual del T-SQL fuente (limitacion heredada, no introducida por
--   la traduccion): si el usuario filtra por IdCountry, el motor fallara en runtime
--   por falta del alias `cou` -- mismo comportamiento que tendria el reporte
--   original en SQL Server.
-- JsonParameters: {     "Column":[        {           "Name":"voucherConsecutive",           "Title":"Recibo de Caja",           "Type":"System.String",           "Format":""        },        {           "Name":"pDate",           "Title":"Fecha Pago",           "Type":"System.String",           "Format":""        },        {           "Name":"contractConsecutive",           "Title":"Contrato",           "Type":"System.String",           "Format":""        },     {           "Name":"mPay",           "Title":"Plataforma",           "Type":"System.String",           "Format":""        },        {           "Name":"nuip",           "Title":"Nuip",           "Type":"System.Int64",           "Format":""        },        {           "Name":"personName",           "Title":"Nombre",           "Type":"System.String",           "Format":""        },        {           "Name":"invoiceConsecutive",           "Title":"Factura",           "Type":"System.String",           "Format":""        },        {           "Name":"term",           "Title":"Servicio",           "Type":"System.String",           "Format":""        },        {           "Name":"descripction",           "Title":"Concepto",           "Type":"System.String",           "Format":""        },        {           "Name":"payValue",           "Title":"Valor Pagado",           "Type":"System.Decimal",           "Format":"Currency"        },           {           "Name":"state",           "Title":"Departamento",           "Type":"System.String",           "Format":""        },        {           "Name":"city",           "Title":"Ciudad",           "Type":"System.String",           "Format":""        },        {           "Name":"neighborhood",           "Title":"Barrio",           "Type":"System.String",           "Format":""        },        {           "Name":"title",           "Title":"Zona",           "Type":"System.String",           "Format":""        }       ],     "Filter":{        "Geographic":true,        "CorporateLocation":false,        "Employee":false,        "Date":false,        "DateRange":true,        "DateTimeRange":false,        "Debt":false     }  }
---
with "VO" as (
  select
    "Voucher"."IdVoucher",
    sum("VoucherPaymentMethods"."PayValue") as "TotalPayValue",
    "Terms"."Term" as "Term"
  from "Voucher"
  inner join "VoucherPaymentMethods"
    on "VoucherPaymentMethods"."IdVoucher" = "Voucher"."IdVoucher"
   and "VoucherPaymentMethods"."IdTermTypePaymentMethod" = 143
  inner join "Terms" on "Terms"."IdTerms" = "VoucherPaymentMethods"."IdTermBank"
  {WHERE2}
  group by "Voucher"."IdVoucher", "VoucherPaymentMethods"."IdTermTypePaymentMethod", "Terms"."Term"
),
"VOC" as (
  select
    com.*,
    vo."TotalPayValue",
    vo."Term"
  from "Voucher" as com
  inner join "VO" as vo on vo."IdVoucher" = com."IdVoucher"
)
select
  "Voucher"."IdVoucher",
  concat(
    extract(year from "Voucher"."PayDate")::text, '-',
    (array['enero','febrero','marzo','abril','mayo','junio','julio','agosto',
           'septiembre','octubre','noviembre','diciembre'])[extract(month from "Voucher"."PayDate")::int], '-',
    lpad(extract(day from "Voucher"."PayDate")::text, 2, '0')
  ) as "pDate",
  concat("Voucher".prefix, '-', "Voucher"."Consecutive"::text) as "voucherConsecutive",
  "Person"."Nuip"::bigint as "nuip",
  concat("Person"."Name", ' ', "Person"."SurName") as "personName",
  concat("Invoice"."Prefix", '-', "Invoice"."Consecutive"::text) as "invoiceConsecutive",
  concat(com.prefix, '-', com."Consecutive"::text) as "contractConsecutive",
  "InvoiceDetail"."Descripction"::text as "descripction",
  "Voucher"."TotalPayValue"::numeric as "payValue",
  "Voucher"."Term"::text as "mPay",
  sta."State"::text as "state",
  cit."City"::text as "city",
  nei."Neighborhood"::text as "neighborhood",
  zon."Title"::text as "title",
  "Terms"."Term"::text as "term"
from "VOC" as "Voucher"
inner join "Contract" as com on com."IdContract" = "Voucher"."IdContract"
inner join "Person" on "Person"."IdPerson" = com."IdPerson"
inner join "Address" on "Address"."IdAddress" = com."IdAddressInstalation"
inner join "Neighborhood" as nei on nei."IdNeighborhood" = "Address"."IdNeighborhood"
inner join "Zone" as zon on zon."IdZone" = nei."IdZone"
inner join "City" as cit on cit."IdCity" = nei."IdCity"
inner join "State" as sta on sta."IdState" = cit."IdState"
inner join "VoucherDetail" on "VoucherDetail"."IdVoucher" = "Voucher"."IdVoucher"
inner join "InvoiceDetail" on "InvoiceDetail"."IdInvoiceDetail" = "VoucherDetail"."IdInvoiceDetail"
inner join "Invoice" on "Invoice"."IdInvoice" = "InvoiceDetail"."IdInvoice"
inner join "GenericService" on "GenericService"."idItem" = "InvoiceDetail"."IdItem"
inner join "Terms" on "Terms"."IdTerms" = "GenericService"."idTermGenericService"
{WHERE1}
order by "Voucher"."IdVoucher"
