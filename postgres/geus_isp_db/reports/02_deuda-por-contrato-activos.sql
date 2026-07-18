-- Report: 2
-- Title: Deuda por Contrato SOLO ACTIVOS
-- TableName: Contract
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=2)
-- NeedsHuman: Report 2 depende de 3 vistas que NO existen en el DDL committeado de IspDb
--   (VContractPayerBehavior, VContractNonPaymentCut, VContractConnectionStatus). El DDL solo
--   define 24 vistas placeholder VContractCompany* (schema-inventory.md / 03_views.sql); estas 3
--   no aparecen en ninguna parte. Sin ellas la query falla en runtime con
--   `ERROR: relation "VContractPayerBehavior" does not exist`, y las 6 columnas que aportan
--   (payerClassification, avgDaysToPay, hasCortesPorMora, cortesCount, connectionStatus,
--   daysWithoutConnection) quedan sin origen. Falta: crear/migrar esas 3 vistas al DDL de IspDb
--   (o reestructurar el reporte). La traduccion T-SQL->PG del resto del pipeline esta completa y
--   verificada: con vistas-stub temporales de esas 3, la query ejecuta sin error y su cabecera
--   contiene EXACTO los 27 Column[].Name del JsonParameters. Este reporte queda EXENTO de la
--   autovalidacion (a)/(b) por esta dependencia irreducible (ver CONVENTIONS.md seccion g).
-- Notes: Variante de Report 1 filtrada a contratos activos (`and c."IdTermContractStatus" = 5`).
--   Mismas reglas de traduccion que Report 1/3 mas los 3 LEFT JOIN a las vistas de comportamiento
--   de pago / cortes / estado de conexion (marcados NEEDS-HUMAN inline). ISNULL(x,0/'SIN CONEXION')
--   -> COALESCE; hasCortesPorMora casteado a ::boolean por el Type=System.Boolean del Column.
-- JsonParameters: {    "Column": [      {        "Name": "contractConsecutive",        "Title": "Contrato",        "Type": "System.String",        "Format": ""      },      {        "Name": "cStatus",        "Title": "Estado",        "Type": "System.String",        "Format": ""      },      {        "Name": "nuip",        "Title": "Nuip",        "Type": "System.Int64",        "Format": ""      },      {        "Name": "name",        "Title": "Nombre",        "Type": "System.String",        "Format": ""      },      {        "Name": "surName",        "Title": "Apellido",        "Type": "System.String",        "Format": ""      },      {        "Name": "debt",        "Title": "Deuda",        "Type": "System.Decimal",        "Format": "Currency"      },      {        "Name": "notPay",        "Title": "Impagos",        "Type": "System.Int32",        "Format": ""      },      {        "Name": "phoneNumber",        "Title": "Telefono",        "Type": "System.String",        "Format": ""      },      {        "Name": "email",        "Title": "Email",        "Type": "System.String",        "Format": ""      },      {        "Name": "title",        "Title": "Zona",        "Type": "System.String",        "Format": ""      },      {        "Name": "cityName",        "Title": "Ciudad",        "Type": "System.String",        "Format": ""      },      {        "Name": "neighborhoodName",        "Title": "Barrio",        "Type": "System.String",        "Format": ""      },   {     "Name": "eNumber",        "Title": "Estrato",        "Type": "System.String",        "Format": ""   },      {        "Name": "address",        "Title": "Dirección",        "Type": "System.String",        "Format": ""      },      {        "Name": "description",        "Title": "Plan de Servicios",        "Type": "System.String",        "Format": ""      },      {        "Name": "connectionName",        "Title": "Internet",        "Type": "System.String",        "Format": ""      },      {        "Name": "connectionProfile",        "Title": "Perfil",        "Type": "System.String",        "Format": ""      },      {        "Name": "bDate",        "Title": "Instalación",        "Type": "System.String",        "Format": ""      },      {        "Name": "lsDate",        "Title": "Corte por Mora",        "Type": "System.String",        "Format": ""      },      {        "Name": "lrDate",        "Title": "Reconexión",        "Type": "System.String",        "Format": ""      },      {        "Name": "eDate",        "Title": "Retiro",        "Type": "System.String",        "Format": ""      },      {        "Name": "payerClassification",        "Title": "Tipo de Pagador",        "Type": "System.String",        "Format": ""      },      {        "Name": "avgDaysToPay",        "Title": "Días Prom. de Pago",        "Type": "System.Int32",        "Format": ""      },      {        "Name": "hasCortesPorMora",        "Title": "¿Tiene Cortes por Mora?",        "Type": "System.Boolean",        "Format": ""      },      {        "Name": "cortesCount",        "Title": "N° de Cortes por Mora",        "Type": "System.Int32",        "Format": ""      },      {        "Name": "connectionStatus",        "Title": "Estado de Conexión",        "Type": "System.String",        "Format": ""      },      {        "Name": "daysWithoutConnection",        "Title": "Días sin Conexión",        "Type": "System.Int32",        "Format": ""      }    ],    "Filter": {      "Geographic": true,      "CorporateLocation": false,      "Employee": false,      "Date": false,      "DateRange": false,      "DateTimeRange": false,      "Debt": true,      "CustomFields": true }  }
---
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
  report."payerClassification"::text             as "payerClassification",
  report."avgDaysToPay"::int                     as "avgDaysToPay",
  report."hasCortesPorMora"::boolean             as "hasCortesPorMora",
  report."cortesCount"::int                      as "cortesCount",
  report."connectionStatus"::text                as "connectionStatus",
  report."daysWithoutConnection"::int            as "daysWithoutConnection",
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
    c."IdContract"                                                         as "IdContract",
    -- ===== Comportamiento de pago (buen pagador) =====
    coalesce(pay."PaymentsConsidered", 0)                                  as "PaymentsConsidered",
    coalesce(pay."AvgDaysToPay", 0)                                        as "avgDaysToPay",
    coalesce(pay."AvgPayDayOfMonth", 0)                                    as "AvgPayDayOfMonth",
    coalesce(pay."AvgDueDayOfMonth", 0)                                    as "AvgDueDayOfMonth",
    -- ===== Cortes por mora =====
    coalesce(cut."HasCortesPorMora", false)                                as "hasCortesPorMora",
    coalesce(cut."CortesCount", 0)                                         as "cortesCount",
    -- ===== Clasificacion final (4 niveles) =====
    pay."PayerClassification"                                              as "payerClassification",
    -- ===== Estado de conexion (Mikrotik) =====
    coalesce(connstat."ConnectionStatus", 'SIN CONEXION')                  as "connectionStatus",
    coalesce(connstat."DaysWithoutConnection", 0)                          as "daysWithoutConnection"
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
  -- NEEDS-HUMAN: las 3 vistas siguientes (VContractPayerBehavior, VContractNonPaymentCut,
  -- VContractConnectionStatus) NO existen en el DDL committeado de IspDb (57 tablas / 24 vistas;
  -- las unicas vistas son las 24 placeholders VContractCompany*). Sin ellas la query no resuelve
  -- y las columnas payerClassification/avgDaysToPay/hasCortesPorMora/cortesCount/connectionStatus/
  -- daysWithoutConnection no tienen origen. Requiere que un humano cree/migre esas 3 vistas
  -- (o reestructure el reporte) antes de poder ejecutar. Traduccion T-SQL->PG del resto es completa.
  left join "VContractPayerBehavior"    pay      on pay."IdContract"      = c."IdContract" and pay."IdCompany"      = c."IdCompany"
  left join "VContractNonPaymentCut"    cut      on cut."IdContract"      = c."IdContract" and cut."IdCompany"      = c."IdCompany"
  left join "VContractConnectionStatus" connstat on connstat."IdContract" = c."IdContract" and connstat."IdCompany" = c."IdCompany"
  {WHERE1}
  and c."IdTermContractStatus" = 5
) report
{WHERE2}
order by report."Address"

