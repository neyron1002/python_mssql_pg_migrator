-- Report: 9
-- Title: Support Ticket Solicitado Detallado
-- TableName: SupporTicket
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=9)
-- Notes: Igual estructura que el reporte 8 (lote #temp -> WITH/CTEs por LEY CRITICA (c)),
--   con estas diferencias del original: el CTE base "ST" NO filtra Done=1 y su columna
--   "Date" sale de DateCreate (no Schedule_Date); en la proyeccion final dateF,
--   solutionTime y secondsSolutionTime van envueltos en IIF(Done=1, ..., 'Pendiente'/0)
--   -> CASE WHEN com."Done" = true. hashAudit (HASHBYTES SHA2_256) -> lower(encode(
--   digest(...,'sha256'),'hex')) via pgcrypto; solo lo consumia el bloque de auditoria
--   inter-base (Geus_ISP_Audit_DB) que queda comentado /* */ conservando la 2a
--   ocurrencia de {WHERE1} (where1Count=2). {WHERE2} filtra "Date" (DateRange).
-- JsonParameters: {   "Column": [    {     "Name": "prefix",     "Title": "ST Prefijo",     "Type": "System.String",     "Format": ""    },    {     "Name": "consecutive",     "Title": "ST Consecutivo",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "typeTicket",     "Title": "Tipo",     "Type": "System.String",     "Format": ""    },    {     "Name": "ticketAction",     "Title": "Accion",     "Type": "System.String",     "Format": ""    },    {     "Name": "typeReason",     "Title": "Razón",     "Type": "System.String",     "Format": ""    },    {     "Name": "userApp",     "Title": "Usuario Agendo",     "Type": "System.String",     "Format": ""    },    {     "Name": "dateI",     "Title": "Fecha Creacion",     "Type": "System.String",     "Format": ""    },    {     "Name": "dateF",     "Title": "Fecha Ejecución",     "Type": "System.String",     "Format": ""    },      {     "Name": "solutionTime",     "Title": "Tiempo Solucion",     "Type": "System.String",     "Format": ""    },      {     "Name": "secondsSolutionTime",     "Title": "Tiempo Solucion (s)",     "Type": "System.Int32",     "Format": ""    },      {     "Name": "techName",     "Title": "Técnico",     "Type": "System.String",     "Format": ""    },      {     "Name": "startDateTime",     "Title": "Fecha Hora Inicio",     "Type": "System.String",     "Format": ""    },    {     "Name": "endDateTime",     "Title": "Fecha Hora Finalizo",     "Type": "System.String",     "Format": ""    },    {     "Name": "minutes",     "Title": "Tiempo  Ejecucion / Min",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "notes",     "Title": "Notas",     "Type": "System.String",     "Format": ""    },        {     "Name": "contractConsecutive",     "Title": "Contrato",     "Type": "System.String",     "Format": ""    },    {     "Name": "nuip",     "Title": "NUIP",     "Type": "System.Int64",     "Format": ""    },    {     "Name": "name",     "Title": "Nombres",     "Type": "System.String",     "Format": ""    },    {     "Name": "surname",     "Title": "Apellidos",     "Type": "System.String",     "Format": ""    },    {     "Name": "city",     "Title": "Ciudad",     "Type": "System.String",     "Format": ""    },    {     "Name": "title",     "Title": "Zona",     "Type": "System.String",     "Format": ""    },    {     "Name": "neighborhood",     "Title": "Barrio",     "Type": "System.String",     "Format": ""    },    {     "Name": "address",     "Title": "Direccion",     "Type": "System.String",     "Format": ""    }     ],   "Filter": {    "Geographic":false,    "CorporateLocation":false,    "Employee":false,    "Date": false,    "DateRange": true,    "DateTimeRange": false,    "Debt": false   }  }
---
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
