-- Report: 12
-- Title: Tecnicos Reportando
-- TableName: SupportTicket
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=12)
-- Notes: Lote T-SQL multi-#temp -> unico statement con WITH/CTEs (LEY CRITICA (c)).
--   Dos ocurrencias de {WHERE1} (CTE "EMPLOYEE" y "SPT", cada una con su propio alias
--   com sobre Employee / SupportTicket) y dos de {WHERE2} (CTE "SPT" y "STL", cada una
--   sobre un FROM que expone la columna citada "Date"; Filter.Date=true -> el motor
--   inyecta where "Date" = @Date). ROW_NUMBER() OVER(PARTITION BY ... ORDER BY ... DESC)
--   es estandar en PG, solo se ajustan identificadores. FORMAT(f,'yyyy-MM-dd hh:mm tt')
--   -> to_char(f,'YYYY-MM-DD HH12:MI AM'). Item.IdItem -> item."idItem" (case real del
--   DDL). El parser de direccion (CHARINDEX 3-arg) se conserva por fidelidad aunque la
--   proyeccion final use a."Address" (direccion cruda) como en el original.
-- JsonParameters: {   "Column": [    {     "Name": "TecName",     "Title": "Tecnico",     "Type": "System.String",     "Format": ""    },    {     "Name": "Contract",     "Title": "Contrato",     "Type": "System.String",     "Format": ""    },    {     "Name": "SupportTicket",     "Title": "Ticket",     "Type": "System.String",     "Format": ""    },    {     "Name": "ItemName",     "Title": "Tipo de Ticket",     "Type": "System.String",     "Format": ""    },    {     "Name": "ScheduleDate",     "Title": "Fecha y hora programada",     "Type": "System.String",     "Format": ""    },    {     "Name": "StartDateTime",     "Title": "Fecha y hora reporte",     "Type": "System.String",     "Format": ""    },    {     "Name": "Address",     "Title": "Direccion",     "Type": "System.String",     "Format": ""    },    {     "Name": "TSTTerm",     "Title": "Estado Ticket",     "Type": "System.String",     "Format": ""    },      {     "Name": "TecStatus",     "Title": "Estado Tecnico",     "Type": "System.String",     "Format": ""    },    {     "Name": "Latitude",     "Title": "Latitud GPS",     "Type": "System.Decimal",     "Format": ""    },    {     "Name": "Longitude",     "Title": "Longitud GPS",     "Type": "System.Decimal",     "Format": ""    }   ],   "Filter": {    "Geographic":false,    "CorporateLocation":false,    "Employee":false,    "Date": true,    "DateRange": false,    "DateTimeRange": false,    "Debt": false   }  }
---
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
