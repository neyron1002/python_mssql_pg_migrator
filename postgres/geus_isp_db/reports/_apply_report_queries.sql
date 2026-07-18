-- =====================================================================
-- _apply_report_queries.sql
-- ---------------------------------------------------------------------
-- ENTREGABLE DE MIGRACION DE DATOS de la columna Report."Query".
--
-- Proposito: reemplazar en la tabla "Report" el T-SQL almacenado como
-- DATO (dialecto SQL Server) por su equivalente PostgreSQL traducido, para
-- los 20 reportes dinamicos de produccion de IspDb (Geus_ISP_DB). Cada
-- query conserva LITERALES los placeholders {WHERE1}/{WHERE2} que el motor
-- ISP.Api.Data/Repositories/ReportsRepository.cs resuelve en runtime.
--
-- Fuente versionada de cada query: los archivos NN_<slug>.sql de este
-- mismo directorio (ver README.md). Este script es la proyeccion de esos
-- artefactos sobre la tabla "Report" — aplicar UNA vez sobre la base de
-- datos migrada a PostgreSQL.
--
-- Cada query PG viaja en un dollar-quoted string $rq$...$rq$ (verificado:
-- ninguna query contiene la secuencia $rq$).
--
-- Reportes aplicados (OK): 17.  Excluidos (NEEDS-HUMAN): 3
--   -> [2, 14, 15] (ver detalle al final del script).
-- =====================================================================

-- La columna "Query" es character varying(6000) en 01_schema.sql, pero al
-- menos una query PG traducida supera ese limite (max = 9584 chars, p.ej.
-- R8/R9 'Support Ticket ... Detallado'). Se amplia a text UNA sola vez para
-- poder almacenar las queries completas sin truncarlas.
ALTER TABLE "Report" ALTER COLUMN "Query" TYPE text;

-- Report 1: Deuda por Contrato TODOS  (fuente: 01_deuda-por-contrato-todos.sql)
UPDATE "Report" SET "Query" = $rq$
select
  report."contractConsecutive"::text            as "contractConsecutive",
  report."cStatus"::text                        as "cStatus",
  report."cAction"::text                         as "cAction",
  report."cActionDate"::text                     as "cActionDate",
  report."nuip"::bigint                          as "nuip",
  report."name"::text                            as "name",
  report."surName"::text                         as "surName",
  report."Debt"::numeric                         as "debt",
  report."NotPay"::int                           as "notPay",
  report."phoneNumber"::text                     as "phoneNumber",
  report."email"::text                           as "email",
  report."title"::text                           as "title",
  report."cityName"::text                        as "cityName",
  report."neighborhoodName"::text                as "neighborhoodName",
  report."eNumber"::text                         as "eNumber",
  report."Address"::text                         as "address",
  report."description"::text                     as "description",
  report."connectionName"::text                  as "connectionName",
  report."connectionProfile"::text               as "connectionProfile",
  report."bDate"::text                           as "bDate",
  report."lsDate"::text                          as "lsDate",
  report."lrDate"::text                          as "lrDate",
  report."eDate"::text                           as "eDate",
  report."IdContract"::bigint                    as "IdContract"
from (
  select
    upper(concat(c.prefix, '-', c."Consecutive"))                          as "contractConsecutive",
    p."Nuip"                                                               as "nuip",
    case when p."TypePerson" = 2 then p."BusinessName" else p."Name" end   as "name",
    case when p."TypePerson" = 2 then p."BusinessName" else p."SurName" end as "surName",
    zon."Title"                                                            as "title",
    cit."City"                                                             as "cityName",
    nei."Neighborhood"                                                     as "neighborhoodName",
    a."AddressName"                                                        as "Address",
    phone."PhoneNumber"                                                    as "phoneNumber",
    email."Email"                                                          as "email",
    pla."Description"                                                      as "description",
    coalesce(i.debt, 0)                                                    as "Debt",
    coalesce(i0."NotPay", 0)                                               as "NotPay",
    to_char(c."BeginDate", 'YYYY-MM-DD')                                   as "bDate",
    to_char(suspensiondatetime."LsDate", 'YYYY-MM-DD')                     as "lsDate",
    to_char(reconnectiondatetime."LrDate", 'YYYY-MM-DD')                   as "lrDate",
    to_char(c."EndDate", 'YYYY-MM-DD')                                     as "eDate",
    upper(terms."Term")                                                    as "cStatus",
    upper(t."Term")                                                        as "cAction",
    to_char(c."LastExecutionDateTime", 'YYYY-MM-DD')                       as "cActionDate",
    case
      when length(case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'Name') end) > 0
        then case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'Name') end
      else case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'onus', '0', 'unique_external_id') end
    end                                                                    as "connectionName",
    case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'Profile') end as "connectionProfile",
    ts."Term"                                                              as "eNumber",
    c."IdContract"                                                         as "IdContract"
  from "Contract" c
  left join (
    select "IdContract", sum("TotalInvoice" - "TotalPay") as debt, count("IdInvoice") as "invoiceNotPay"
    from "Invoice"
    where "Pay" = false
    group by "IdContract"
  ) i on i."IdContract" = c."IdContract"
  left join (
    select "IdContract", count("IdContract") as "NotPay"
    from (
      select "IdContract"
      from "InvoiceRecurrent"
      where "pay" = false
      group by "IdContract", extract(year from "date"), extract(month from "date")
    ) t00
    group by "IdContract"
  ) i0 on i0."IdContract" = c."IdContract"
  inner join "Person" p on p."IdPerson" = c."IdPerson"
  left join (
    select st1."IdPerson", string_agg(st1."PhoneNumber"::text, '-' order by st1."IdPerson") as "PhoneNumber"
    from "PersonPhoneNumber" st1
    group by st1."IdPerson"
  ) phone on phone."IdPerson" = p."IdPerson"
  left join (
    select "IdPerson", max("Email") as "Email"
    from "PersonEmail"
    group by "IdPerson"
  ) email on email."IdPerson" = p."IdPerson"
  left join (
    select st."IdContract", tt."idTermTicketAction", max(st."Schedule_Date") as "LrDate"
    from "SupportTicket" st
    inner join "TicketType" tt on tt."idItem" = st."IdItemTypeSupportTicket"
    where tt."idTermTicketAction" = 35 and st."Done" = true and st."IdTermTicketScheduleType" = 14
    group by st."IdContract", tt."idTermTicketAction"
  ) reconnectiondatetime on reconnectiondatetime."IdContract" = c."IdContract"
  left join (
    select st."IdContract", max(st."Schedule_Date") as "LsDate"
    from "SupportTicket" st
    inner join "TicketType" tt on tt."idItem" = st."IdItemTypeSupportTicket"
    where (tt."idTermTicketAction" = 48 or tt."idTermTicketAction" = 49) and st."Done" = true and st."IdTermTicketScheduleType" = 14
    group by st."IdContract"
  ) suspensiondatetime on suspensiondatetime."IdContract" = c."IdContract"
  inner join "Company" com on com."IdCompany" = c."IdCompany"
  inner join (
    select t4.*,
      btrim(substring(t4."Address" from t4."PNeighborhoodName" + 1 for (length(t4."Address") - t4."PNeighborhoodName" + 1))) as "AddressName",
      (case when strpos(substring(t4."Address" from t4."PNeighborhoodName" + 1), ',') = 0 then 0 else strpos(substring(t4."Address" from t4."PNeighborhoodName" + 1), ',') + t4."PNeighborhoodName" end) as "PAddressName"
    from (
      select t3.*,
        (case when strpos(substring(t3."Address" from t3."PCityName" + 1), ',') = 0 then 0 else strpos(substring(t3."Address" from t3."PCityName" + 1), ',') + t3."PCityName" end) as "PNeighborhoodName"
      from (
        select t2.*,
          (case when strpos(substring(t2."Address" from t2."PStateName" + 1), ',') = 0 then 0 else strpos(substring(t2."Address" from t2."PStateName" + 1), ',') + t2."PStateName" end) as "PCityName"
        from (
          select t1.*,
            (case when strpos(substring(t1."Address" from t1."PCountryName" + 1), ',') = 0 then 0 else strpos(substring(t1."Address" from t1."PCountryName" + 1), ',') + t1."PCountryName" end) as "PStateName"
          from (
            select "Address".*, strpos("Address"."Address", ',') as "PCountryName"
            from "Address"
          ) t1
        ) t2
      ) t3
    ) t4
  ) a on a."IdAddress" = c."IdAddressInstalation"
  left join "Terms" ts on ts."IdTerms" = a."IdTermSocioeconomic"
  inner join "Neighborhood" nei on nei."IdNeighborhood" = a."IdNeighborhood"
  left join "Zone" zon on zon."IdZone" = nei."IdZone"
  inner join "City" cit on cit."IdCity" = nei."IdCity"
  inner join "State" sta on sta."IdState" = cit."IdState"
  inner join "Country" cou on cou."IdCountry" = sta."IdCountry"
  inner join "PlanService" pla on pla."IdPlanService" = c."IdPlanService"
  inner join "Terms" terms on terms."IdTerms" = c."IdTermContractStatus"
  inner join "Terms" t on t."IdTerms" = c."IdTermTicketAction"
  left join "ContractConnection" cc on cc."IdContract" = c."IdContract"
  {WHERE1}
) report
{WHERE2}
order by report."Address"
$rq$ WHERE "IdReport" = 1;

-- Report 3: Deuda por Contrato SOLO INACTIVOS  (fuente: 03_deuda-por-contrato-inactivos.sql)
UPDATE "Report" SET "Query" = $rq$
select
  report."contractConsecutive"::text            as "contractConsecutive",
  report."cStatus"::text                        as "cStatus",
  report."nuip"::bigint                          as "nuip",
  report."name"::text                            as "name",
  report."surName"::text                         as "surName",
  report."Debt"::numeric                         as "debt",
  report."NotPay"::int                           as "notPay",
  report."phoneNumber"::text                     as "phoneNumber",
  report."email"::text                           as "email",
  report."title"::text                           as "title",
  report."cityName"::text                        as "cityName",
  report."neighborhoodName"::text                as "neighborhoodName",
  report."eNumber"::text                         as "eNumber",
  report."Address"::text                         as "address",
  report."description"::text                     as "description",
  report."connectionName"::text                  as "connectionName",
  report."connectionProfile"::text               as "connectionProfile",
  report."bDate"::text                           as "bDate",
  report."lsDate"::text                          as "lsDate",
  report."lrDate"::text                          as "lrDate",
  report."eDate"::text                           as "eDate",
  report."IdContract"::bigint                    as "IdContract"
from (
  select
    upper(concat(c.prefix, '-', c."Consecutive"))                          as "contractConsecutive",
    p."Nuip"                                                               as "nuip",
    case when p."TypePerson" = 2 then p."BusinessName" else p."Name" end   as "name",
    case when p."TypePerson" = 2 then p."BusinessName" else p."SurName" end as "surName",
    zon."Title"                                                            as "title",
    cit."City"                                                             as "cityName",
    nei."Neighborhood"                                                     as "neighborhoodName",
    a."AddressName"                                                        as "Address",
    phone."PhoneNumber"                                                    as "phoneNumber",
    email."Email"                                                          as "email",
    pla."Description"                                                      as "description",
    coalesce(i.debt, 0)                                                    as "Debt",
    coalesce(i0."NotPay", 0)                                               as "NotPay",
    to_char(c."BeginDate", 'YYYY-MM-DD')                                   as "bDate",
    to_char(suspensiondatetime."LsDate", 'YYYY-MM-DD')                     as "lsDate",
    to_char(reconnectiondatetime."LrDate", 'YYYY-MM-DD')                   as "lrDate",
    to_char(c."EndDate", 'YYYY-MM-DD')                                     as "eDate",
    upper(terms."Term")                                                    as "cStatus",
    case
      when length(case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'Name') end) > 0
        then case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'Name') end
      else case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'onus', '0', 'unique_external_id') end
    end                                                                    as "connectionName",
    case when cc."JsonParameters" is null or btrim(cc."JsonParameters") = '' then null else jsonb_extract_path_text(cc."JsonParameters"::jsonb, 'Profile') end as "connectionProfile",
    ts."Term"                                                              as "eNumber",
    c."IdContract"                                                         as "IdContract"
  from "Contract" c
  left join (
    select "IdContract", sum("TotalInvoice" - "TotalPay") as debt, count("IdInvoice") as "invoiceNotPay"
    from "Invoice"
    where "Pay" = false
    group by "IdContract"
  ) i on i."IdContract" = c."IdContract"
  left join (
    select "IdContract", count("IdContract") as "NotPay"
    from (
      select "IdContract"
      from "InvoiceRecurrent"
      where "pay" = false
      group by "IdContract", extract(year from "date"), extract(month from "date")
    ) t00
    group by "IdContract"
  ) i0 on i0."IdContract" = c."IdContract"
  inner join "Person" p on p."IdPerson" = c."IdPerson"
  left join (
    select st1."IdPerson", string_agg(st1."PhoneNumber"::text, '-' order by st1."IdPerson") as "PhoneNumber"
    from "PersonPhoneNumber" st1
    group by st1."IdPerson"
  ) phone on phone."IdPerson" = p."IdPerson"
  left join (
    select "IdPerson", max("Email") as "Email"
    from "PersonEmail"
    group by "IdPerson"
  ) email on email."IdPerson" = p."IdPerson"
  left join (
    select st."IdContract", tt."idTermTicketAction", max(st."Schedule_Date") as "LrDate"
    from "SupportTicket" st
    inner join "TicketType" tt on tt."idItem" = st."IdItemTypeSupportTicket"
    where tt."idTermTicketAction" = 35 and st."Done" = true and st."IdTermTicketScheduleType" = 14
    group by st."IdContract", tt."idTermTicketAction"
  ) reconnectiondatetime on reconnectiondatetime."IdContract" = c."IdContract"
  left join (
    select st."IdContract", tt."idTermTicketAction", max(st."Schedule_Date") as "LsDate"
    from "SupportTicket" st
    inner join "TicketType" tt on tt."idItem" = st."IdItemTypeSupportTicket"
    where tt."idTermTicketAction" = 48 and st."Done" = true and st."IdTermTicketScheduleType" = 14
    group by st."IdContract", tt."idTermTicketAction"
  ) suspensiondatetime on suspensiondatetime."IdContract" = c."IdContract"
  inner join "Company" com on com."IdCompany" = c."IdCompany"
  inner join (
    select t4.*,
      btrim(substring(t4."Address" from t4."PNeighborhoodName" + 1 for (length(t4."Address") - t4."PNeighborhoodName" + 1))) as "AddressName",
      (case when strpos(substring(t4."Address" from t4."PNeighborhoodName" + 1), ',') = 0 then 0 else strpos(substring(t4."Address" from t4."PNeighborhoodName" + 1), ',') + t4."PNeighborhoodName" end) as "PAddressName"
    from (
      select t3.*,
        (case when strpos(substring(t3."Address" from t3."PCityName" + 1), ',') = 0 then 0 else strpos(substring(t3."Address" from t3."PCityName" + 1), ',') + t3."PCityName" end) as "PNeighborhoodName"
      from (
        select t2.*,
          (case when strpos(substring(t2."Address" from t2."PStateName" + 1), ',') = 0 then 0 else strpos(substring(t2."Address" from t2."PStateName" + 1), ',') + t2."PStateName" end) as "PCityName"
        from (
          select t1.*,
            (case when strpos(substring(t1."Address" from t1."PCountryName" + 1), ',') = 0 then 0 else strpos(substring(t1."Address" from t1."PCountryName" + 1), ',') + t1."PCountryName" end) as "PStateName"
          from (
            select "Address".*, strpos("Address"."Address", ',') as "PCountryName"
            from "Address"
          ) t1
        ) t2
      ) t3
    ) t4
  ) a on a."IdAddress" = c."IdAddressInstalation"
  left join "Terms" ts on ts."IdTerms" = a."IdTermSocioeconomic"
  inner join "Neighborhood" nei on nei."IdNeighborhood" = a."IdNeighborhood"
  left join "Zone" zon on zon."IdZone" = nei."IdZone"
  inner join "City" cit on cit."IdCity" = nei."IdCity"
  inner join "State" sta on sta."IdState" = cit."IdState"
  inner join "Country" cou on cou."IdCountry" = sta."IdCountry"
  inner join "PlanService" pla on pla."IdPlanService" = c."IdPlanService"
  inner join "Terms" terms on terms."IdTerms" = c."IdTermContractStatus"
  left join "ContractConnection" cc on cc."IdContract" = c."IdContract"
  {WHERE1}
  and c."IdTermContractStatus" = 6
) report
{WHERE2}
order by report."Address"
$rq$ WHERE "IdReport" = 3;

-- Report 4: Materiales  (fuente: 04_materiales.sql)
UPDATE "Report" SET "Query" = $rq$
select
  "idMaterial"::text as "idMaterial",
  "name"::text as "name",
  (sum("quantity"))::int as "qty"
from (
  select
    com."IdCompany",
    com."IdEmployee",
    com."IdContract",
    com."Schedule_Date" as "Date",
    com."idMaterial",
    com."name",
    com."quantity"
  from (
    select
      t1."IdCompany",
      t1."IdContract",
      t1."IdSupportTicket",
      t1."IdEmployee",
      t1."Schedule_Date",
      mat."idMaterial",
      mat."name",
      mat."quantity"
    from (
      select
        "IdSupportTicket",
        "IdContract",
        "IdCompany",
        "IdEmployee",
        "DateCreate",
        "Schedule_Date",
        "IdTermTicketScheduleType",
        case when jsonb_typeof("JSONPayload"::jsonb -> 'materials') = 'array'
             then "JSONPayload"::jsonb -> 'materials'
             else '[]'::jsonb
        end as json
      from "SupportTicket"
      where "JSONPayload" is not null
        and "Done" = true
        and "IdTermTicketScheduleType" = 14
    ) t1
    cross join lateral jsonb_to_recordset(t1.json) as mat("idMaterial" text, "name" text, "quantity" int)
  ) com
  inner join "Employee" as emp on emp."IdEmployee" = com."IdEmployee"
  inner join "Contract" on "Contract"."IdContract" = com."IdContract"
  inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
  inner join "Neighborhood" nei on nei."IdNeighborhood" = "Address"."IdNeighborhood"
  inner join "Zone" zon on zon."IdZone" = nei."IdZone"
  inner join "City" cit on cit."IdCity" = nei."IdCity"
  inner join "State" sta on sta."IdState" = cit."IdState"
  inner join "Country" cou on cou."IdCountry" = sta."IdCountry"
  {WHERE1}
) t2
{WHERE2}
group by "idMaterial", "name"
order by "name"
$rq$ WHERE "IdReport" = 4;

-- Report 5: Materiales Detallado  (fuente: 05_materiales-detallado.sql)
UPDATE "Report" SET "Query" = $rq$
select * from (
  select
    com."IdCompany",
    com."IdEmployee",
    com."Schedule_Date" as "Date",
    to_char(com."Schedule_Date", 'YYYY-MM-DD HH12:MI AM') as "dateTimeDone",
    "Item"."ItemName"::text as "itemName",
    concat(com.prefix, '-', com."Consecutive"::text) as "conSupporTicket",
    concat("Contract".prefix, '-', "Contract"."Consecutive"::text) as "conContract",
    concat("Person"."SurName", ', ', "Person"."Name") as "subscriberName",
    "Person"."Nuip"::bigint as "nuip",
    concat(tec."SurName", ', ', tec."Name") as "technicianName",
    zon."Title"::text as "title",
    "Address"."Address"::text as "address",
    com."name"::text as "materialName",
    com."quantity"::int as "quantity"
  from (
    select
      t1."IdCompany",
      t1."IdContract",
      t1."IdSupportTicket",
      t1."IdEmployee",
      t1."Schedule_Date",
      t1."Consecutive",
      t1.prefix,
      t1."IdItemTypeSupportTicket",
      mat."idMaterial",
      mat."name",
      mat."quantity"
    from (
      select
        "IdSupportTicket",
        "Consecutive",
        prefix,
        "IdContract",
        "IdCompany",
        "IdEmployee",
        "DateCreate",
        "Schedule_Date",
        "IdTermTicketScheduleType",
        "IdItemTypeSupportTicket",
        case when jsonb_typeof("JSONPayload"::jsonb -> 'materials') = 'array'
             then "JSONPayload"::jsonb -> 'materials'
             else '[]'::jsonb
        end as json
      from "SupportTicket"
      where "JSONPayload" is not null
        and "Done" = true
        and "IdTermTicketScheduleType" = 14
    ) t1
    cross join lateral jsonb_to_recordset(t1.json) as mat("idMaterial" text, "name" text, "quantity" int)
  ) com
  inner join "Item" on "Item"."idItem" = com."IdItemTypeSupportTicket"
  inner join "Employee" as emp on emp."IdEmployee" = com."IdEmployee"
  inner join "Person" as tec on tec."IdPerson" = emp."IdPerson"
  inner join "Contract" on "Contract"."IdContract" = com."IdContract"
  inner join "Person" on "Person"."IdPerson" = "Contract"."IdPerson"
  inner join "Address" on "Address"."IdAddress" = "Contract"."IdAddressInstalation"
  inner join "Neighborhood" nei on nei."IdNeighborhood" = "Address"."IdNeighborhood"
  inner join "Zone" zon on zon."IdZone" = nei."IdZone"
  inner join "City" cit on cit."IdCity" = nei."IdCity"
  inner join "State" sta on sta."IdState" = cit."IdState"
  inner join "Country" cou on cou."IdCountry" = sta."IdCountry"
  {WHERE1}
) t2
{WHERE2}
order by "Date" desc
$rq$ WHERE "IdReport" = 5;

-- Report 6: Pagos Online  (fuente: 06_pagos-online.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 6;

-- Report 7: Cierre de cajas C  (fuente: 07_cierre-de-cajas.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 7;

-- Report 8: Support Ticket Ejecutado Detallado  (fuente: 08_support-ticket-ejecutado-detallado.sql)
UPDATE "Report" SET "Query" = $rq$
WITH "ST" AS (
    SELECT st0.*,
           lower(encode(digest(concat(lower(st0."IdCompany"::text), 'SupportTicket', st0."IdSupportTicket"::text), 'sha256'), 'hex')) AS hashaudit
    FROM (
        SELECT item."ItemName" AS "typeTicket",
               terms."Term"    AS "typeReason",
               ttt."Term"      AS "ticketAction",
               com.*,
               cast(com."Schedule_Date" AS date) AS "Date"
        FROM "SupportTicket" AS com
        INNER JOIN "Terms" terms ON terms."IdTerms" = com."IdTermTicketScheduleType"
        INNER JOIN "Item" item ON item."idItem" = com."IdItemTypeSupportTicket"
        LEFT JOIN "TicketType" tt ON tt."idItem" = com."IdItemTypeSupportTicket"
        LEFT JOIN "Terms" ttt ON ttt."IdTerms" = tt."idTermTicketAction"
        {WHERE1}
        AND com."Done" = true
    ) st0
    {WHERE2}
),
/*  Bloque de auditoria (inter-base Geus_ISP_Audit_DB.Audit): irreducible en una sola
    conexion PG (requiere dblink/postgres_fdw no provisto). Se conserva comentado igual
    que en el T-SQL original; su placeholder de tenant mantiene where1Count=2.
    SELECT a.* FROM (
      SELECT t0."IdSupportTicket", com.*, CAST(com."DateTime" AS date) AS "Date"
      FROM Audit AS com
      INNER JOIN (
        SELECT st."IdSupportTicket", com."CompanyEntityHash", MIN("IdAudit") firstidaudit
        FROM Audit AS com
        INNER JOIN "ST" st ON st.hashaudit = com."CompanyEntityHash"
        {WHERE1}
        and "TableName" = 'SupportTicket'
        group by com."CompanyEntityHash", st."IdSupportTicket"
      ) t0 on t0.firstidaudit = com."IdAudit"
    ) a  */
"STS" AS (
    SELECT t1.* FROM (
        SELECT com.*,
               lower(encode(digest(concat(lower(t0."IdCompany"::text), 'SupportTicketSchedule', t0.lidschedule::text), 'sha256'), 'hex')) AS hashaudit,
               t0."IdCompany"
        FROM "SupportTicketSchedule" AS com
        INNER JOIN (
            SELECT st."IdSupportTicket", st."IdCompany", MIN(sts."IdSchedule") AS lidschedule
            FROM "SupportTicketSchedule" sts
            INNER JOIN "ST" st ON st."IdSupportTicket" = sts."IdSupportTicket"
                AND sts."IdTermTicketScheduleType" IN (13, 14)
            GROUP BY st."IdSupportTicket", st."IdCompany"
        ) t0 ON t0.lidschedule = com."IdSchedule"
    ) t1
),
"STS2" AS (
    SELECT t1.* FROM (
        SELECT com.*,
               lower(encode(digest(concat(lower(t0."IdCompany"::text), 'SupportTicketSchedule', t0.lidschedule::text), 'sha256'), 'hex')) AS hashaudit,
               t0."IdCompany"
        FROM "SupportTicketSchedule" AS com
        INNER JOIN (
            SELECT st."IdSupportTicket", st."IdCompany", MAX(sts."IdSchedule") AS lidschedule
            FROM "SupportTicketSchedule" sts
            INNER JOIN "ST" st ON st."IdSupportTicket" = sts."IdSupportTicket"
                AND sts."IdTermTicketScheduleType" IN (40, 118)
            GROUP BY st."IdSupportTicket", st."IdCompany"
        ) t0 ON t0.lidschedule = com."IdSchedule"
    ) t1
),
"STT" AS (
    SELECT sts2."IdSupportTicket",
           stl."IdSupportTicketSchedule",
           COALESCE((sum(stl."DurationTime") / 60), 0) AS minutes,
           min(stl."StartDateTime") AS startdatetime,
           max(stl."EndDateTime")   AS enddatetime
    FROM "SupportTicketScheduleTechnicianLog" stl
    INNER JOIN "STS2" sts2 ON sts2."IdSchedule" = stl."IdSupportTicketSchedule"
    GROUP BY stl."IdSupportTicketSchedule", sts2."IdSupportTicket"
),
"dContract" AS (
    SELECT a2.*
    FROM (
        SELECT c."IdContract",
               UPPER(CONCAT(c.prefix, '-', c."Consecutive")) AS "ContractConsecutive",
               p."Nuip" AS "Nuip",
               p."Name" AS "Name",
               p."SurName" AS "SurName",
               cit."City"          AS "City",
               nei."Neighborhood"  AS "Neighborhood",
               zon."Title"         AS "Title",
               a."AddressName"     AS "Address"
        FROM "Contract" c
        INNER JOIN "Person" p ON p."IdPerson" = c."IdPerson"
        INNER JOIN "Company" com ON com."IdCompany" = c."IdCompany"
        INNER JOIN (
            SELECT t4.*,
                   btrim(substring(t4."Address" FROM t4.pneighborhoodname + 1 FOR length(t4."Address") - t4.pneighborhoodname + 1)) AS "AddressName",
                   (CASE WHEN POSITION(',' IN substring(t4."Address" FROM t4.pneighborhoodname + 1)) = 0 THEN 0
                         ELSE POSITION(',' IN substring(t4."Address" FROM t4.pneighborhoodname + 1)) + t4.pneighborhoodname + 1 - 1 END) AS paddressname
            FROM (
                SELECT t3.*,
                       (CASE WHEN POSITION(',' IN substring(t3."Address" FROM t3.pcityname + 1)) = 0 THEN 0
                             ELSE POSITION(',' IN substring(t3."Address" FROM t3.pcityname + 1)) + t3.pcityname + 1 - 1 END) AS pneighborhoodname
                FROM (
                    SELECT t2.*,
                           (CASE WHEN POSITION(',' IN substring(t2."Address" FROM t2.pstatename + 1)) = 0 THEN 0
                                 ELSE POSITION(',' IN substring(t2."Address" FROM t2.pstatename + 1)) + t2.pstatename + 1 - 1 END) AS pcityname
                    FROM (
                        SELECT t1.*,
                               (CASE WHEN POSITION(',' IN substring(t1."Address" FROM t1.pcountryname + 1)) = 0 THEN 0
                                     ELSE POSITION(',' IN substring(t1."Address" FROM t1.pcountryname + 1)) + t1.pcountryname + 1 - 1 END) AS pstatename
                        FROM (
                            SELECT adr.*,
                                   (CASE WHEN POSITION(',' IN adr."Address") = 0 THEN 0
                                         ELSE POSITION(',' IN adr."Address") END) AS pcountryname
                            FROM "Address" adr
                        ) t1
                    ) t2
                ) t3
            ) t4
        ) a ON a."IdAddress" = c."IdAddressFacturation"
        INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = a."IdNeighborhood"
        INNER JOIN "City" cit ON cit."IdCity" = nei."IdCity"
        INNER JOIN "Zone" zon ON zon."IdZone" = nei."IdZone"
        WHERE c."IdContract" IN (SELECT st."IdContract" FROM "ST" st)
    ) a2
)
SELECT
    com."prefix"::text                                                           AS "prefix",
    com."Consecutive"::bigint                                                    AS "consecutive",
    com."typeTicket"::text                                                       AS "typeTicket",
    com."ticketAction"::text                                                     AS "ticketAction",
    com."typeReason"::text                                                       AS "typeReason",
    ''::text                                                                     AS "userApp",
    to_char(com."DateCreate", 'YYYY-MM-DD HH12:MI AM')::text                     AS "dateI",
    to_char(com."Schedule_Date", 'YYYY-MM-DD HH12:MI AM')::text                  AS "dateF",
    (
        (trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint / 86400)::text || ' d '
        || lpad(((trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint % 86400) / 3600)::text, 2, '0') || ' h '
        || lpad(((trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint % 3600) / 60)::text, 2, '0') || ' m '
        || lpad((trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint % 60)::text, 2, '0') || ' s'
    )::text                                                                      AS "solutionTime",
    trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::int     AS "secondsSolutionTime",
    CONCAT(pers."Name", ' ', pers."SurName")::text                               AS "techName",
    COALESCE(to_char(stt.startdatetime, 'YYYY-MM-DD HH12:MI AM'), '')::text      AS "startDateTime",
    COALESCE(to_char(stt.enddatetime, 'YYYY-MM-DD HH12:MI AM'), '')::text        AS "endDateTime",
    COALESCE(stt.minutes, 0)::bigint                                             AS "minutes",
    concat(com."SubscriberNotes", chr(13), com."TechnicianNotes", chr(13), sts."Description")::text AS "notes",
    dc."ContractConsecutive"::text                                              AS "contractConsecutive",
    dc."Nuip"::bigint                                                            AS "nuip",
    dc."Name"::text                                                             AS "name",
    dc."SurName"::text                                                           AS "surname",
    dc."City"::text                                                             AS "city",
    dc."Title"::text                                                            AS "title",
    dc."Neighborhood"::text                                                     AS "neighborhood",
    dc."Address"::text                                                          AS "address"
FROM "ST" AS com
INNER JOIN "dContract" AS dc ON dc."IdContract" = com."IdContract"
INNER JOIN "Employee" e ON e."IdEmployee" = com."IdEmployee"
INNER JOIN "Person" pers ON pers."IdPerson" = e."IdPerson"
LEFT JOIN "STS" sts ON sts."IdSupportTicket" = com."IdSupportTicket"
LEFT JOIN "STT" stt ON stt."IdSupportTicket" = com."IdSupportTicket"
ORDER BY "dateF"
$rq$ WHERE "IdReport" = 8;

-- Report 9: Support Ticket Solicitado Detallado  (fuente: 09_support-ticket-solicitado-detallado.sql)
UPDATE "Report" SET "Query" = $rq$
WITH "ST" AS (
    SELECT st0.*,
           lower(encode(digest(concat(lower(st0."IdCompany"::text), 'SupportTicket', st0."IdSupportTicket"::text), 'sha256'), 'hex')) AS hashaudit
    FROM (
        SELECT item."ItemName" AS "typeTicket",
               terms."Term"    AS "typeReason",
               ttt."Term"      AS "ticketAction",
               com.*,
               cast(com."DateCreate" AS date) AS "Date"
        FROM "SupportTicket" AS com
        INNER JOIN "Terms" terms ON terms."IdTerms" = com."IdTermTicketScheduleType"
        INNER JOIN "Item" item ON item."idItem" = com."IdItemTypeSupportTicket"
        LEFT JOIN "TicketType" tt ON tt."idItem" = com."IdItemTypeSupportTicket"
        LEFT JOIN "Terms" ttt ON ttt."IdTerms" = tt."idTermTicketAction"
        {WHERE1}
    ) st0
    {WHERE2}
),
/*  Bloque de auditoria (inter-base Geus_ISP_Audit_DB.Audit): irreducible en una sola
    conexion PG (requiere dblink/postgres_fdw no provisto). Se conserva comentado igual
    que en el T-SQL original; su placeholder de tenant mantiene where1Count=2.
    SELECT a.* FROM (
      SELECT t0."IdSupportTicket", com.*, CAST(com."DateTime" AS date) AS "Date"
      FROM Audit AS com
      INNER JOIN (
        SELECT st."IdSupportTicket", com."CompanyEntityHash", MIN("IdAudit") firstidaudit
        FROM Audit AS com
        INNER JOIN "ST" st ON st.hashaudit = com."CompanyEntityHash"
        {WHERE1}
        and "TableName" = 'SupportTicket'
        group by com."CompanyEntityHash", st."IdSupportTicket"
      ) t0 on t0.firstidaudit = com."IdAudit"
    ) a  */
"STS" AS (
    SELECT t1.* FROM (
        SELECT com.*,
               lower(encode(digest(concat(lower(t0."IdCompany"::text), 'SupportTicketSchedule', t0.lidschedule::text), 'sha256'), 'hex')) AS hashaudit,
               t0."IdCompany"
        FROM "SupportTicketSchedule" AS com
        INNER JOIN (
            SELECT st."IdSupportTicket", st."IdCompany", MIN(sts."IdSchedule") AS lidschedule
            FROM "SupportTicketSchedule" sts
            INNER JOIN "ST" st ON st."IdSupportTicket" = sts."IdSupportTicket"
                AND sts."IdTermTicketScheduleType" IN (13, 14)
            GROUP BY st."IdSupportTicket", st."IdCompany"
        ) t0 ON t0.lidschedule = com."IdSchedule"
    ) t1
),
"STS2" AS (
    SELECT t1.* FROM (
        SELECT com.*,
               lower(encode(digest(concat(lower(t0."IdCompany"::text), 'SupportTicketSchedule', t0.lidschedule::text), 'sha256'), 'hex')) AS hashaudit,
               t0."IdCompany"
        FROM "SupportTicketSchedule" AS com
        INNER JOIN (
            SELECT st."IdSupportTicket", st."IdCompany", MAX(sts."IdSchedule") AS lidschedule
            FROM "SupportTicketSchedule" sts
            INNER JOIN "ST" st ON st."IdSupportTicket" = sts."IdSupportTicket"
                AND sts."IdTermTicketScheduleType" IN (40, 118)
            GROUP BY st."IdSupportTicket", st."IdCompany"
        ) t0 ON t0.lidschedule = com."IdSchedule"
    ) t1
),
"STT" AS (
    SELECT sts2."IdSupportTicket",
           stl."IdSupportTicketSchedule",
           COALESCE((sum(stl."DurationTime") / 60), 0) AS minutes,
           min(stl."StartDateTime") AS startdatetime,
           max(stl."EndDateTime")   AS enddatetime
    FROM "SupportTicketScheduleTechnicianLog" stl
    INNER JOIN "STS2" sts2 ON sts2."IdSchedule" = stl."IdSupportTicketSchedule"
    GROUP BY stl."IdSupportTicketSchedule", sts2."IdSupportTicket"
),
"dContract" AS (
    SELECT a2.*
    FROM (
        SELECT c."IdContract",
               UPPER(CONCAT(c.prefix, '-', c."Consecutive")) AS "ContractConsecutive",
               p."Nuip" AS "Nuip",
               p."Name" AS "Name",
               p."SurName" AS "SurName",
               cit."City"          AS "City",
               nei."Neighborhood"  AS "Neighborhood",
               zon."Title"         AS "Title",
               a."AddressName"     AS "Address"
        FROM "Contract" c
        INNER JOIN "Person" p ON p."IdPerson" = c."IdPerson"
        INNER JOIN "Company" com ON com."IdCompany" = c."IdCompany"
        INNER JOIN (
            SELECT t4.*,
                   btrim(substring(t4."Address" FROM t4.pneighborhoodname + 1 FOR length(t4."Address") - t4.pneighborhoodname + 1)) AS "AddressName",
                   (CASE WHEN POSITION(',' IN substring(t4."Address" FROM t4.pneighborhoodname + 1)) = 0 THEN 0
                         ELSE POSITION(',' IN substring(t4."Address" FROM t4.pneighborhoodname + 1)) + t4.pneighborhoodname + 1 - 1 END) AS paddressname
            FROM (
                SELECT t3.*,
                       (CASE WHEN POSITION(',' IN substring(t3."Address" FROM t3.pcityname + 1)) = 0 THEN 0
                             ELSE POSITION(',' IN substring(t3."Address" FROM t3.pcityname + 1)) + t3.pcityname + 1 - 1 END) AS pneighborhoodname
                FROM (
                    SELECT t2.*,
                           (CASE WHEN POSITION(',' IN substring(t2."Address" FROM t2.pstatename + 1)) = 0 THEN 0
                                 ELSE POSITION(',' IN substring(t2."Address" FROM t2.pstatename + 1)) + t2.pstatename + 1 - 1 END) AS pcityname
                    FROM (
                        SELECT t1.*,
                               (CASE WHEN POSITION(',' IN substring(t1."Address" FROM t1.pcountryname + 1)) = 0 THEN 0
                                     ELSE POSITION(',' IN substring(t1."Address" FROM t1.pcountryname + 1)) + t1.pcountryname + 1 - 1 END) AS pstatename
                        FROM (
                            SELECT adr.*,
                                   (CASE WHEN POSITION(',' IN adr."Address") = 0 THEN 0
                                         ELSE POSITION(',' IN adr."Address") END) AS pcountryname
                            FROM "Address" adr
                        ) t1
                    ) t2
                ) t3
            ) t4
        ) a ON a."IdAddress" = c."IdAddressFacturation"
        INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = a."IdNeighborhood"
        INNER JOIN "City" cit ON cit."IdCity" = nei."IdCity"
        INNER JOIN "Zone" zon ON zon."IdZone" = nei."IdZone"
        WHERE c."IdContract" IN (SELECT st."IdContract" FROM "ST" st)
    ) a2
)
SELECT
    com."prefix"::text                                                           AS "prefix",
    com."Consecutive"::bigint                                                    AS "consecutive",
    com."typeTicket"::text                                                       AS "typeTicket",
    com."ticketAction"::text                                                     AS "ticketAction",
    com."typeReason"::text                                                       AS "typeReason",
    ''::text                                                                     AS "userApp",
    to_char(com."DateCreate", 'YYYY-MM-DD HH12:MI AM')::text                     AS "dateI",
    (CASE WHEN com."Done" = true
          THEN to_char(com."Schedule_Date", 'YYYY-MM-DD HH12:MI AM')
          ELSE 'Pendiente' END)::text                                           AS "dateF",
    (CASE WHEN com."Done" = true THEN (
        (trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint / 86400)::text || ' d '
        || lpad(((trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint % 86400) / 3600)::text, 2, '0') || ' h '
        || lpad(((trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint % 3600) / 60)::text, 2, '0') || ' m '
        || lpad((trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::bigint % 60)::text, 2, '0') || ' s'
    ) ELSE 'Pendiente' END)::text                                               AS "solutionTime",
    (CASE WHEN com."Done" = true
          THEN trunc(EXTRACT(EPOCH FROM (com."Schedule_Date" - com."DateCreate")))::int
          ELSE 0 END)::int                                                      AS "secondsSolutionTime",
    CONCAT(pers."Name", ' ', pers."SurName")::text                               AS "techName",
    COALESCE(to_char(stt.startdatetime, 'YYYY-MM-DD HH12:MI AM'), '')::text      AS "startDateTime",
    COALESCE(to_char(stt.enddatetime, 'YYYY-MM-DD HH12:MI AM'), '')::text        AS "endDateTime",
    COALESCE(stt.minutes, 0)::bigint                                             AS "minutes",
    concat(com."SubscriberNotes", chr(13), com."TechnicianNotes", chr(13), sts."Description")::text AS "notes",
    dc."ContractConsecutive"::text                                              AS "contractConsecutive",
    dc."Nuip"::bigint                                                            AS "nuip",
    dc."Name"::text                                                             AS "name",
    dc."SurName"::text                                                           AS "surname",
    dc."City"::text                                                             AS "city",
    dc."Title"::text                                                            AS "title",
    dc."Neighborhood"::text                                                     AS "neighborhood",
    dc."Address"::text                                                          AS "address"
FROM "ST" AS com
INNER JOIN "dContract" AS dc ON dc."IdContract" = com."IdContract"
INNER JOIN "Employee" e ON e."IdEmployee" = com."IdEmployee"
INNER JOIN "Person" pers ON pers."IdPerson" = e."IdPerson"
LEFT JOIN "STS" sts ON sts."IdSupportTicket" = com."IdSupportTicket"
LEFT JOIN "STT" stt ON stt."IdSupportTicket" = com."IdSupportTicket"
ORDER BY "dateF"
$rq$ WHERE "IdReport" = 9;

-- Report 10: Reporte Especial FE  (fuente: 10_reporte-especial-fe.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 10;

-- Report 11: Usuarios Activos por Zona y Servicio  (fuente: 11_usuarios-activos-por-zona-y-servicio.sql)
UPDATE "Report" SET "Query" = $rq$
select
  zon."Title"::text as "title",
  terms."Term"::text as "status",
  ts."Term"::text as "service",
  (count(c."IdContract"))::int as "qty"
from "Contract" as c
inner join "Company" com on com."IdCompany" = c."IdCompany"
inner join "Address" a on a."IdAddress" = c."IdAddressFacturation"
inner join "Neighborhood" nei on nei."IdNeighborhood" = a."IdNeighborhood"
left join "Zone" zon on zon."IdZone" = nei."IdZone"
inner join "City" cit on cit."IdCity" = nei."IdCity"
inner join "State" sta on sta."IdState" = cit."IdState"
inner join "Country" cou on cou."IdCountry" = sta."IdCountry"
inner join "PlanService" pla on pla."IdPlanService" = c."IdPlanService"
inner join "PlanServiceDetail" on "PlanServiceDetail"."IdPlanService" = c."IdPlanService"
inner join "GenericService" on "GenericService"."idItem" = "PlanServiceDetail"."IdItemService"
inner join "Terms" as ts on ts."IdTerms" = "GenericService"."idTermGenericService"
inner join "Terms" as terms on terms."IdTerms" = c."IdTermContractStatus"
{WHERE1}
group by zon."Title", terms."Term", ts."Term"
order by zon."Title", terms."Term", ts."Term"
$rq$ WHERE "IdReport" = 11;

-- Report 12: Tecnicos Reportando  (fuente: 12_tecnicos-reportando.sql)
UPDATE "Report" SET "Query" = $rq$
WITH "EMPLOYEE" AS (
    SELECT com."IdEmployee", pers.*
    FROM "Employee" AS com
    INNER JOIN "Person" pers ON pers."IdPerson" = com."IdPerson"
    {WHERE1}
    AND com."IdTermJobPosition" = 10
),
"SPT" AS (
    SELECT * FROM (
        SELECT com."IdSupportTicket",
               sched."IdSchedule",
               sched."ScheduleDate",
               com."IdTermTicketScheduleType",
               tst."Term" AS "TSTTerm",
               sched."IdEmployee",
               com."IdContract",
               com."Consecutive" AS "STConsecutive",
               com.prefix       AS "STPrefix",
               com."IdItemTypeSupportTicket",
               item."ItemName",
               CAST(com."Schedule_Date" AS date) AS "Date"
        FROM "SupportTicketSchedule" sched
        INNER JOIN "SupportTicket" AS com ON com."IdSupportTicket" = sched."IdSupportTicket"
        INNER JOIN "Terms" tst ON tst."IdTerms" = com."IdTermTicketScheduleType"
        INNER JOIN "Item" item ON item."idItem" = com."IdItemTypeSupportTicket"
        {WHERE1}
        AND sched."IdTermTicketScheduleType" IN (118, 40)
    ) t0
    {WHERE2}
),
"STL" AS (
    SELECT t0."IdSupportTicketSchedule",
           t0."IdEmployee",
           t0."IdTermTypeSupportTicketScheduleTechnicianLog",
           MAX(t0."StartDateTime") AS sdt
    FROM (
        SELECT stl.*, CAST(stl."StartDateTime" AS date) AS "Date"
        FROM "SupportTicketScheduleTechnicianLog" stl
        INNER JOIN "SPT" spt ON spt."IdSchedule" = stl."IdSupportTicketSchedule"
    ) t0
    {WHERE2}
    GROUP BY t0."IdSupportTicketSchedule", t0."IdEmployee", t0."IdTermTypeSupportTicketScheduleTechnicianLog"
),
"SC" AS (
    SELECT t0.*,
           terms."Term",
           stl."StartDateTime",
           stl."Latitude",
           stl."Longitude"
    FROM (
        SELECT stl2.*,
               ROW_NUMBER() OVER (PARTITION BY stl2."IdEmployee" ORDER BY stl2.sdt DESC) AS rn
        FROM "STL" stl2
    ) t0
    INNER JOIN "SupportTicketScheduleTechnicianLog" stl
        ON stl."IdSupportTicketSchedule" = t0."IdSupportTicketSchedule"
        AND stl."IdEmployee" = t0."IdEmployee"
        AND stl."IdTermTypeSupportTicketScheduleTechnicianLog" = t0."IdTermTypeSupportTicketScheduleTechnicianLog"
        AND stl."StartDateTime" = t0.sdt
    INNER JOIN "Terms" terms ON terms."IdTerms" = stl."IdTermTypeSupportTicketScheduleTechnicianLog"
    WHERE t0.rn = 1
),
"dContract" AS (
    SELECT a2.*
    FROM (
        SELECT c."IdContract",
               UPPER(CONCAT(c.prefix, '-', c."Consecutive")) AS "ContractConsecutive",
               p."Nuip" AS "Nuip",
               p."Name" AS "Name",
               p."SurName" AS "SurName",
               cit."City"          AS "City",
               nei."Neighborhood"  AS "Neighborhood",
               zon."Title"         AS "Title",
               a."Address"         AS "Address"
        FROM "Contract" c
        INNER JOIN "Person" p ON p."IdPerson" = c."IdPerson"
        INNER JOIN "Company" com ON com."IdCompany" = c."IdCompany"
        INNER JOIN (
            SELECT t4.*,
                   btrim(substring(t4."Address" FROM t4.pneighborhoodname + 1 FOR length(t4."Address") - t4.pneighborhoodname + 1)) AS "AddressName",
                   (CASE WHEN POSITION(',' IN substring(t4."Address" FROM t4.pneighborhoodname + 1)) = 0 THEN 0
                         ELSE POSITION(',' IN substring(t4."Address" FROM t4.pneighborhoodname + 1)) + t4.pneighborhoodname + 1 - 1 END) AS paddressname
            FROM (
                SELECT t3.*,
                       (CASE WHEN POSITION(',' IN substring(t3."Address" FROM t3.pcityname + 1)) = 0 THEN 0
                             ELSE POSITION(',' IN substring(t3."Address" FROM t3.pcityname + 1)) + t3.pcityname + 1 - 1 END) AS pneighborhoodname
                FROM (
                    SELECT t2.*,
                           (CASE WHEN POSITION(',' IN substring(t2."Address" FROM t2.pstatename + 1)) = 0 THEN 0
                                 ELSE POSITION(',' IN substring(t2."Address" FROM t2.pstatename + 1)) + t2.pstatename + 1 - 1 END) AS pcityname
                    FROM (
                        SELECT t1.*,
                               (CASE WHEN POSITION(',' IN substring(t1."Address" FROM t1.pcountryname + 1)) = 0 THEN 0
                                     ELSE POSITION(',' IN substring(t1."Address" FROM t1.pcountryname + 1)) + t1.pcountryname + 1 - 1 END) AS pstatename
                        FROM (
                            SELECT adr.*,
                                   (CASE WHEN POSITION(',' IN adr."Address") = 0 THEN 0
                                         ELSE POSITION(',' IN adr."Address") END) AS pcountryname
                            FROM "Address" adr
                        ) t1
                    ) t2
                ) t3
            ) t4
        ) a ON a."IdAddress" = c."IdAddressFacturation"
        INNER JOIN "Neighborhood" nei ON nei."IdNeighborhood" = a."IdNeighborhood"
        INNER JOIN "City" cit ON cit."IdCity" = nei."IdCity"
        INNER JOIN "Zone" zon ON zon."IdZone" = nei."IdZone"
        WHERE c."IdContract" IN (SELECT spt."IdContract" FROM "SPT" spt)
    ) a2
),
"SPTE" AS (
    SELECT spt."IdEmployee", COUNT(spt."IdSupportTicket") AS "SP"
    FROM "SPT" spt
    GROUP BY spt."IdEmployee"
)
SELECT
    emp."IdEmployee"                                            AS "IdEmployee",
    CONCAT(emp."SurName", ', ', emp."Name")::text               AS "TecName",
    dc."ContractConsecutive"::text                              AS "Contract",
    CONCAT(spt."STPrefix", '-', spt."STConsecutive")::text      AS "SupportTicket",
    spt."ItemName"::text                                        AS "ItemName",
    to_char(spt."ScheduleDate", 'YYYY-MM-DD HH12:MI AM')::text  AS "ScheduleDate",
    to_char(sc."StartDateTime", 'YYYY-MM-DD HH12:MI AM')::text  AS "StartDateTime",
    dc."Title"::text                                            AS "Title",
    dc."Neighborhood"::text                                     AS "Neighborhood",
    dc."Address"::text                                          AS "Address",
    spt."TSTTerm"::text                                         AS "TSTTerm",
    spt."IdSupportTicket"                                       AS "IdSupportTicket",
    sc."IdSupportTicketSchedule"                                AS "IdSupportTicketSchedule",
    sc."Term"::text                                             AS "TecStatus",
    COALESCE(sc."Latitude", 0)::numeric                         AS "Latitude",
    COALESCE(sc."Longitude", 0)::numeric                        AS "Longitude"
FROM "SPTE" spte
INNER JOIN "EMPLOYEE" emp ON emp."IdEmployee" = spte."IdEmployee"
LEFT JOIN "SC" sc ON sc."IdEmployee" = spte."IdEmployee"
LEFT JOIN "SPT" spt ON spt."IdSchedule" = sc."IdSupportTicketSchedule"
LEFT JOIN "dContract" dc ON dc."IdContract" = spt."IdContract"
$rq$ WHERE "IdReport" = 12;

-- Report 13: Reporte de Gastos Detallado  (fuente: 13_reporte-de-gastos-detallado.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 13;

-- Report 16: Reporte BANCOLOMBIA  (fuente: 16_reporte-bancolombia.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 16;

-- Report 17: Recaudo por Oficina  (fuente: 17_recaudo-por-oficina.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 17;

-- Report 18: Recaudo por Oficina, Cajero y Medio de Pago  (fuente: 18_recaudo-por-oficina-cajero-y-medio-de-pago.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 18;

-- Report 19: Recaudo por Oficina, Cajero y Servicio  (fuente: 19_recaudo-por-oficina-cajero-y-servicio.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 19;

-- Report 20: Recaudo por Fecha y Oficina  (fuente: 20_recaudo-por-fecha-y-oficina.sql)
UPDATE "Report" SET "Query" = $rq$
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
$rq$ WHERE "IdReport" = 20;

-- =====================================================================
-- EXCLUIDOS — NEEDS-HUMAN (dependencia irreducible; NO se aplican aqui)
-- =====================================================================
-- Report 2: Deuda por Contrato SOLO ACTIVOS
--   Report 2 depende de 3 vistas ausentes del DDL committeado de IspDb
--   (VContractPayerBehavior, VContractNonPaymentCut,
--   VContractConnectionStatus): aportan
--   payerClassification/avgDaysToPay/hasCortesPorMora/cortesCount, etc. Sin
--   ellas la query falla en runtime. Provisionar/migrar esas vistas para
--   poder aplicar.
--
-- Report 14: Reporte de Pagos NEQUI Detallado
--   Report 14 hace INNER JOIN contra Neyron_Nequi_DB.dbo.NequiMessage y
--   Neyron_Nequi_DB.dbo.Term (base de datos distinta de IspDb, ausente del
--   corpus de 57 tablas). term/ResponseDateTime/JSONMessage y el filtro
--   WHERE2 'Date' provienen de ahi; la query no puede correr contra
--   Geus_ISP_DB sola. Requiere postgres_fdw/dblink o reestructuracion
--   app-side.
--
-- Report 15: Recaudo Detallado Incluye Notas Credito
--   Report 15 lee FROM Neyron_DI_DB.dbo.DigitalInvoice (base distinta de
--   IspDb, ausente del DDL) alimentando las columnas FE dip/dic/tdi via LEFT
--   JOIN. El core de recaudo esta traducido; DigitalInvoice debe
--   provisionarse (migrar/postgres_fdw) para aplicar end-to-end.
--
-- Fin del script.
