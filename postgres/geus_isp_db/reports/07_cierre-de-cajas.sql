-- Report: 7
-- Title: Cierre de cajas C
-- TableName: CashRegisterLog
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=7)
-- Notes: T-SQL original era un lote de 4 sentencias (#CRL, #CRLVMP, #CRLVD, SELECT
--   final + 3x DROP TABLE), inejecutable tal cual bajo el protocolo extendido de
--   Npgsql (ver CONVENTIONS.md LEY CRITICA (c)). Traducido a 3 CTE encadenados
--   ("CRL","CRLVMP","CRLVD") + el SELECT final del lote como sentencia principal.
--   {WHERE1} aparece 3 veces (una por CTE), cada una con su propio alias `com`
--   local segun CONVENTIONS.md (a): en "CRL" com=BranchCompany, en "CRLVMP"/
--   "CRLVD" com=Voucher.
--   GOTCHA DE CASE (CONVENTIONS.md (d), verificado contra schema-inventory.md):
--   "BranchCompany" tiene su columna de compania como "idCompany" (i minuscula,
--   typo real del DDL) -- NO "IdCompany" (I mayuscula) como asume el motor al
--   inyectar `com."IdCompany"`. Por eso "CRL" NO alias-ea BranchCompany
--   directamente como com; en su lugar com es una subconsulta derivada
--   `(select "IdBranchCompany", "idCompany" AS "IdCompany", "BranchCompanyName"
--   from "BranchCompany") as com` que reexpone la columna con el case exacto que
--   el placeholder necesita, sin alterar el dato ni el esquema real. "Voucher"
--   (usado como com en CRLVMP/CRLVD) sí tiene "IdCompany" en PascalCase nativo,
--   sin necesidad de este workaround.
--   RESTRUCTURACION DELIBERADA de "{WHERE2} OR date is null": el T-SQL fuente
--   (fila unica en el TSV, SIN saltos de linea reales -- confirmado programaticamente
--   sobre el dump) concatena literalmente `{WHERE2}  OR date is null` justo despues
--   del alias T0. El motor (ReportsRepository.GetQueryWithFilter, leido completo)
--   reemplaza {WHERE2} por "" (cadena vacia) cuando el caller no envia rango de
--   fecha -- lo que produce `... ) t0  OR "date" is null`, un OR colgante sin WHERE
--   precedente: SQL invalido en CUALQUIER motor (no es un problema introducido por
--   esta traduccion; el T-SQL original habria fallado identico en SQL Server si se
--   invocara sin filtro de fecha). Para que el artefacto traducido cumpla el
--   contrato real del motor (que SI puede enviar {WHERE2} vacio) sin fingir "OK" con
--   una sentencia que rompe en ese caso, se reestructura preservando la semantica
--   exacta ("incluir filas dentro del rango O con fecha nula") de forma valida en
--   ambas ramas: "CRL" define un CTE anidado "t0raw" (el SELECT base con {WHERE1})
--   y expone `where "Date" is null or "idCashRegisterLog" in (select
--   "idCashRegisterLog" from "t0raw" {WHERE2})`. Cuando {WHERE2} es "", el
--   subselect retorna TODOS los ids de t0raw (sin filtro) -> el OR es
--   tautologicamente verdadero -> equivale a "sin filtro" (mismo comportamiento
--   que el placeholder vacio en cualquier otro reporte). Cuando {WHERE2} trae el
--   rango de fecha, el subselect retorna solo los ids dentro del rango -> el OR
--   preserva exactamente "dentro del rango O fecha nula". Nested WITH (CTE dentro
--   de CTE) es sintaxis PG valida, verificado.
--   GOTCHA DE CASE #2 (encontrado en autovalidacion con {WHERE2} ACTIVO, no con la
--   neutralizacion vacia): ReportsRepository.GetQueryWithFilter hardcodea el
--   literal `"Date"` (D mayuscula) para el filtro DateRange/Date, sin importar el
--   reporte -- NO es una convencion por reporte, es fijo en el motor (linea con
--   `\"Date\" between @InitDate and @FinishDate`). La columna CAST(DateOpen AS
--   DATE) de "t0raw" se alias-ea por lo tanto exactamente "Date" (no "date" en
--   minuscula); de lo contrario, con un filtro de fecha real la query falla en
--   runtime con `column "Date" does not exist` (confirmado empiricamente: la
--   neutralizacion con {WHERE2} vacio NO ejercita esta ruta porque nunca
--   referencia la columna, asi que un chequeo (a)/(b) solo-vacio la deja pasar en
--   falso; se agrego una segunda pasada de autovalidacion con {WHERE2} NO vacio
--   -- ` where  "Date" between '2023-01-01' and '2023-12-31'`, el texto exacto que
--   produce el motor -- para descubrir y confirmar el fix de este archivo).
--   ISNULL(...,0)->coalesce(...,0); CAST(...AS DATE)->::date;
--   FORMAT(f,'yyyy-MM-dd hh:mm tt')->to_char(f,'YYYY-MM-DD HH12:MI AM').
--   Filter.Geographic=false y Filter.Employee=false para este reporte (verificado
--   en meta.json): no se requieren los alias cou/sta/cit/nei/zon/emp -- coherente
--   con que el T-SQL original tampoco los une. Nota adicional (no bloqueante,
--   heredada del T-SQL original sin alias "cas"): si un caller filtra este
--   reporte por IdCashRegister, el motor inyectaria `and cas."IdCashRegister" =
--   @IdCashRegister` en {WHERE1}, pero ningun alias "cas" existe aqui (CashRegister
--   se une sin alias) -- mismo comportamiento que tendria el T-SQL original (que
--   tampoco lo aliasea "cas"), no es una regresion de esta traduccion.
-- JsonParameters: {     "Column":[        {           "Name":"branchCompanyName",           "Title":"Sucursal",           "Type":"System.String",           "Format":""        },        {           "Name":"officeName",           "Title":"Oficina",           "Type":"System.String",           "Format":""        },        {           "Name":"idCashRegister",           "Title":"# Caja",           "Type":"System.Int32",           "Format":""        },        {           "Name":"hostName",           "Title":"HostName Caja",           "Type":"System.String",           "Format":""        },        {           "Name":"idCashRegisterLog",           "Title":"Consecutivo Caja ",           "Type":"System.Int32",           "Format":""        },     {           "Name":"employee",           "Title":"Cajero",           "Type":"System.String",           "Format":""        },     {           "Name":"dateOpen",           "Title":"Fecha Hora Apertura",           "Type":"System.String",           "Format":""        },     {           "Name":"dateClose",           "Title":"Fecha Hora Cierre",           "Type":"System.String",           "Format":""        },     {           "Name":"initBalance",           "Title":"$ Valor Inicial",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"cashClose",           "Title":"$ Efectivo al Cierre",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"leftBalance",           "Title":"$ Dejado en Caja",           "Type":"System.Decimal",           "Format":"Currency"        },       {           "Name":"totalPay",           "Title":"$ Recaudo Total",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"totalPayCash",           "Title":"$ Recaudo Efectivo",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"totalPayOther",           "Title":"$ Recaudo Otros",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"totalPayNulled",           "Title":"$ Pagos Anulados",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"totalPayCreditNote",           "Title":"$ Notas Credito",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"totalPayCreditNoteOk",           "Title":"$ Notas Credito Aprobadas",           "Type":"System.Decimal",           "Format":"Currency"        },     {           "Name":"totalPayCreditNoteNulled",           "Title":"$ Notas Credito Anuladas",           "Type":"System.Decimal",           "Format":"Currency"        }                 ],     "Filter":{        "Geographic":false,        "CorporateLocation":false,        "Employee":false,        "Date":false,        "DateRange":true,        "DateTimeRange":false,        "Debt":false     }  }
---
with "CRL" as (
  with "t0raw" as (
    select
      com."BranchCompanyName"::text as "branchCompanyName",
      "Office"."OfficeName"::text as "officeName",
      "CashRegister"."IdCashRegister"::int as "idCashRegister",
      "CashRegister"."HostName"::text as "hostName",
      "CashRegisterLog"."IdCashRegisterLog"::int as "idCashRegisterLog",
      concat("Person"."SurName", ', ', "Person"."Name") as "employee",
      to_char("CashRegisterLog"."DateOpen", 'YYYY-MM-DD HH12:MI AM') as "dateOpen",
      to_char("CashRegisterLog"."DateClose", 'YYYY-MM-DD HH12:MI AM') as "dateClose",
      coalesce("CashRegisterLog"."InitBalance", 0)::numeric as "initBalance",
      coalesce("CashRegisterLog"."CashClose", 0)::numeric as "cashClose",
      coalesce("CashRegisterLog"."LeftBalance", 0)::numeric as "leftBalance",
      "CashRegisterLog"."DateOpen"::date as "Date"
    from "CashRegisterLog"
    inner join "CashRegister" on "CashRegister"."IdCashRegister" = "CashRegisterLog"."IdCashRegister"
    inner join "Office" on "Office"."IdOffice" = "CashRegister"."IdOffice"
    inner join (
      select "IdBranchCompany", "idCompany" as "IdCompany", "BranchCompanyName"
      from "BranchCompany"
    ) as com on com."IdBranchCompany" = "Office"."IdBranchCompany"
    inner join "Employee" on "Employee"."IdEmployee" = "CashRegisterLog"."IdEmployee"
    inner join "Person" on "Person"."IdPerson" = "Employee"."IdPerson"
    {WHERE1}
  )
  select * from "t0raw"
  where "Date" is null
     or "idCashRegisterLog" in (
       select "idCashRegisterLog" from "t0raw"
       {WHERE2}
     )
),
"CRLVMP" as (
  select
    com."IdVoucher",
    com."IdCashRegisterLog",
    com."IdTermDocumentType",
    com."IdTermVoucherStatus",
    "VoucherPaymentMethods"."IdTermTypePaymentMethod",
    "VoucherPaymentMethods"."PayValue"
  from "Voucher" as com
  inner join "VoucherPaymentMethods" on "VoucherPaymentMethods"."IdVoucher" = com."IdVoucher"
  inner join "CRL" on "CRL"."idCashRegisterLog" = com."IdCashRegisterLog"
  {WHERE1}
),
"CRLVD" as (
  select
    com."IdVoucher",
    com."IdCashRegisterLog",
    com."IdTermDocumentType",
    com."IdTermVoucherStatus",
    "VoucherDetail"."PayValue"
  from "Voucher" as com
  inner join "VoucherDetail" on "VoucherDetail"."IdVoucher" = com."IdVoucher"
  inner join "CRL" on "CRL"."idCashRegisterLog" = com."IdCashRegisterLog"
  {WHERE1}
)
select * from (
  select
    "CashRegisterLog".*,
    coalesce(t0."TotalPay", 0)::numeric as "totalPay",
    coalesce(t1."TotalPayCash", 0)::numeric as "totalPayCash",
    coalesce(t2."TotalPayOther", 0)::numeric as "totalPayOther",
    coalesce(t5."TotalPayNulled", 0)::numeric as "totalPayNulled",
    coalesce(t6."TotalPayCreditNote", 0)::numeric as "totalPayCreditNote",
    coalesce(t3."TotalPayCreditNoteOk", 0)::numeric as "totalPayCreditNoteOk",
    coalesce(t4."TotalPayCreditNoteNulled", 0)::numeric as "totalPayCreditNoteNulled"
  from "CRL" as "CashRegisterLog"
  inner join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPay"
    from "CRLVD"
    group by "IdCashRegisterLog"
  ) t0 on t0."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
  left join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPayCash"
    from "CRLVMP"
    where "IdTermTypePaymentMethod" = 62 and "IdTermVoucherStatus" = 145
    group by "IdCashRegisterLog"
  ) t1 on t1."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
  left join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPayOther"
    from "CRLVMP"
    where "IdTermTypePaymentMethod" <> 62 and "IdTermVoucherStatus" = 145
    group by "IdCashRegisterLog"
  ) t2 on t2."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
  left join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPayNulled"
    from "CRLVD"
    where "IdTermDocumentType" = 38 and "IdTermVoucherStatus" = 146
    group by "IdCashRegisterLog"
  ) t5 on t5."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
  left join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPayCreditNote"
    from "CRLVD"
    where "IdTermDocumentType" = 115
    group by "IdCashRegisterLog"
  ) t6 on t6."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
  left join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPayCreditNoteOk"
    from "CRLVD"
    where "IdTermDocumentType" = 115 and "IdTermVoucherStatus" = 145
    group by "IdCashRegisterLog"
  ) t3 on t3."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
  left join (
    select "IdCashRegisterLog", sum("PayValue") as "TotalPayCreditNoteNulled"
    from "CRLVD"
    where "IdTermDocumentType" = 115 and "IdTermVoucherStatus" = 146
    group by "IdCashRegisterLog"
  ) t4 on t4."IdCashRegisterLog" = "CashRegisterLog"."idCashRegisterLog"
) tbase
order by "dateOpen" desc
