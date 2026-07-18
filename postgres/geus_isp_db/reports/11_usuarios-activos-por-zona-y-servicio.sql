-- Report: 11
-- Title: Usuarios Activos por Zona y Servicio
-- TableName: Contract
-- Category: 113
-- Source: ia-assets/pg-migration/26.07.18_Reportes.txt (fila IdReport=11)
-- Notes: Sin {WHERE2} (where2Count=0 en meta.json, aunque Filter.Debt=true -- no se
--   inventa el placeholder). Segundo JOIN a "Terms" en el T-SQL original no llevaba
--   alias explicito (`inner join Terms on terms.IdTerms = c.IdTermContractStatus`);
--   SQL Server resolvio esa referencia contra el propio nombre de tabla por ser
--   case-insensitive. En PG se declara explicitamente `AS terms` (alias propio,
--   minuscula, sin comillas) para distinguirlo del segundo JOIN a Terms (alias ts,
--   termino de servicio). LEFT JOIN a "Zone" preservado tal cual (zona puede ser NULL).
-- JsonParameters: {   "Column": [    {     "Name": "title",     "Title": "Zona",     "Type": "System.String",     "Format": ""    },    {     "Name": "status",     "Title": "Estado",     "Type": "System.String",     "Format": ""    },    {     "Name": "service",     "Title": "Servicio",     "Type": "System.String",     "Format": ""    },    {     "Name": "qty",     "Title": "Cantidad",     "Type": "System.Int32",     "Format": ""    }   ],   "Filter": {    "Geographic":true,    "CorporateLocation":false,    "Employee":false,    "Date": false,    "DateRange": false,    "DateTimeRange": false,    "Debt": true   }  }
---
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
