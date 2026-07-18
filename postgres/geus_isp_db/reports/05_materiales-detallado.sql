-- Report: 5
-- Title: Materiales Detallado
-- TableName: SupporTicket
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=5)
-- Notes: Misma extraccion JSON que el reporte 4, INCLUYENDO el fix de
--   `case when jsonb_typeof(x -> 'materials') = 'array' then x -> 'materials' else
--   '[]'::jsonb end` (un `coalesce(x -> 'materials','[]'::jsonb)` simple no cubre
--   `"materials": null` explicito -- lanza `cannot call jsonb_to_recordset on a
--   non-array`; ver detalle completo en las notas de 04_materiales.sql, verificado
--   empiricamente contra pgrep_d). "Item" se une por
--   "Item"."idItem" (PK real en minuscula, sin comillas de mas alla de la cita
--   exacta) = com."IdItemTypeSupportTicket". Se unen dos alias de "Person": `tec`
--   (tecnico que ejecuto, via Employee.IdPerson) y el "Person" sin alias (titular
--   del contrato, via Contract.IdPerson) -- sin colision porque cada referencia
--   esta calificada. SupportTicket.Consecutive es PascalCase citado pero
--   SupportTicket.prefix/Contract.prefix son minuscula sin comillas (typo real del
--   DDL, ver CONVENTIONS.md (d)) -- cast ::text a Consecutive (bigint) antes de
--   concatenar con '-'. `com` (alias fijo del motor) resuelve directo contra
--   "IdCompany" seleccionado desde SupportTicket, sin conflicto de case.
--   La columna "Date" (Schedule_Date renombrada) se expone en el nivel t2 tanto
--   para el filtro {WHERE2} (DateRange) como para el ORDER BY externo.
-- JsonParameters: {   "Column": [    {     "Name": "dateTimeDone",     "Title": "Fecha Ejecucion",     "Type": "System.String",     "Format": ""    },    {     "Name": "conSupporTicket",     "Title": "Ticket",     "Type": "System.String",     "Format": ""    },    {     "Name": "technicianName",     "Title": "Tecnico",     "Type": "System.String",     "Format": ""    },    {     "Name": "itemName",     "Title": "Tipo",     "Type": "System.String",     "Format": ""    },    {     "Name": "conContract",     "Title": "Contrato",     "Type": "System.String",     "Format": ""    },    {     "Name": "nuip",     "Title": "Nuip",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "subscriberName",     "Title": "Nombre Usuario",     "Type": "System.String",     "Format": ""      },{     "Name": "title",     "Title": "Zona",     "Type": "System.String",     "Format": ""    },{     "Name": "address",     "Title": "Direccion",     "Type": "System.String",     "Format": ""    },{     "Name": "materialName",     "Title": "Material",     "Type": "System.String",     "Format": ""    },{     "Name": "quantity",     "Title": "Cantidad",     "Type": "System.Int32",     "Format": ""    }   ],   "Filter": {    "Geographic":true,    "CorporateLocation":false,    "Employee":true,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
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
