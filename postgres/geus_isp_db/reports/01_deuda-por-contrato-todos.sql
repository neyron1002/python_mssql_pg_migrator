-- Report: 1
-- Title: Deuda por Contrato TODOS
-- TableName: Contract
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=1)
-- Notes: Wrapper `select ... from ( <inner {WHERE1}> ) report {WHERE2} order by "Address"`.
--   El inner expone las columnas canonicas "Debt"/"NotPay" (para que {WHERE2} las filtre) y
--   "Address" (para el order by); el SELECT externo re-aliasa a los Column[].Name camelCase del
--   JsonParameters con su cast de tipo. Traducciones T-SQL->PG: ISNULL->COALESCE; IIF->CASE;
--   CAST(FORMAT(f,'yyyy-MM-dd')...)->to_char(f,'YYYY-MM-DD'); JSON_VALUE(col,'$.x')->forma
--   segura CASE WHEN col IS NULL OR btrim(col)='' THEN NULL ELSE col::jsonb #>> '{x}' END
--   (path $.onus[0].unique_external_id -> '{onus,0,unique_external_id}'); agregacion de telefonos
--   FOR XML PATH('')+LEFT/LEN -> string_agg("PhoneNumber"::text, '-' ORDER BY ...) sin recorte;
--   CHARINDEX(sub,str,start) -> strpos(substring(str FROM start),sub)+start-1 via CASE (0 si no halla);
--   year(date)/month(date) -> EXTRACT(YEAR/MONTH FROM "date"); Pay=0 (bit) -> "Pay"=false. Todos los
--   identificadores citados con el case EXACTO del DDL (schema-inventory.md).
-- JsonParameters: {   "Column": [     {       "Name": "contractConsecutive",       "Title": "Contrato",       "Type": "System.String",       "Format": ""     },     {       "Name": "cStatus",       "Title": "Estado",       "Type": "System.String",       "Format": ""     },  {       "Name": "cAction",       "Title": "Evento",       "Type": "System.String",       "Format": ""     },  {       "Name": "cActionDate",       "Title": "Fecha Evento",       "Type": "System.String",       "Format": ""     },     {       "Name": "nuip",       "Title": "Nuip",       "Type": "System.Int64",       "Format": ""     },     {       "Name": "name",       "Title": "Nombre",       "Type": "System.String",       "Format": ""     },     {       "Name": "surName",       "Title": "Apellido",       "Type": "System.String",       "Format": ""     },     {       "Name": "debt",       "Title": "Deuda",       "Type": "System.Decimal",       "Format": "Currency"     },     {       "Name": "notPay",       "Title": "Impagos",       "Type": "System.Int32",       "Format": ""     },     {       "Name": "phoneNumber",       "Title": "Telefono",       "Type": "System.String",       "Format": ""     },     {       "Name": "email",       "Title": "Email",       "Type": "System.String",       "Format": ""     },     {       "Name": "title",       "Title": "Zona",       "Type": "System.String",       "Format": ""     },     {       "Name": "cityName",       "Title": "Ciudad",       "Type": "System.String",       "Format": ""     },     {       "Name": "neighborhoodName",       "Title": "Barrio",       "Type": "System.String",       "Format": ""     },  {    "Name": "eNumber",       "Title": "Estrato",       "Type": "System.String",       "Format": ""  },     {       "Name": "address",       "Title": "Dirección",       "Type": "System.String",       "Format": ""     },     {       "Name": "description",       "Title": "Plan de Servicios",       "Type": "System.String",       "Format": ""     },     {       "Name": "connectionName",       "Title": "Internet",       "Type": "System.String",       "Format": ""     },     {       "Name": "connectionProfile",       "Title": "Perfil",       "Type": "System.String",       "Format": ""     },     {       "Name": "bDate",       "Title": "Instalación",       "Type": "System.String",       "Format": ""     },     {       "Name": "lsDate",       "Title": "Corte por Mora",       "Type": "System.String",       "Format": ""     },     {       "Name": "lrDate",       "Title": "Reconexión",       "Type": "System.String",       "Format": ""     },     {       "Name": "eDate",       "Title": "Retiro",       "Type": "System.String",       "Format": ""     }   ],   "Filter": {     "Geographic": true,     "CorporateLocation": false,     "Employee": false,     "Date": false,     "DateRange": false,     "DateTimeRange": false,     "Debt": true,     "CustomFields": true  } }
---
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

