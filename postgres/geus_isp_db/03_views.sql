-- =====================================================================
-- Geus_ISP_DB  ·  03_views.sql  ·  Reporting views (24)
-- =====================================================================
-- These 24 views back the keyless "VContractCompany*" entities mapped
-- with ToView(...) in IspDbBase (contract installation / reconnection /
-- suspension / withdrawal / summary aggregations by zone/service/period).
--
-- IMPORTANT — STRUCTURAL PLACEHOLDERS:
-- The original aggregate SELECT bodies are NOT present in any available
-- artifact (neither the MSSQL source dumps nor the tested PG corpus under
-- ia-assets/pg-migration/ contain them). To keep the schema EF-complete
-- (so IspDbContext can map and query these entities and the integration
-- suite can assert their presence), each view is emitted with the exact
-- column list + types EF expects but an empty body (WHERE false).
--
-- NEEDS-HUMAN: the real aggregation SQL must be supplied before these
-- views return production data. Structure (columns/types) is correct;
-- only the SELECT logic is a placeholder.
-- =====================================================================

CREATE OR REPLACE VIEW "VContractCompanyInstallationByServiceYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyInstallationByServiceYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS integer) AS "Growth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyInstallationByYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyInstallationByZoneYearMonth" AS
SELECT
    CAST(NULL AS integer) AS "Growth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyInstallationByZoneYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS integer) AS "Growth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyReconectionByServiceYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyReconectionByServiceYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyReconectionByYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyReconectionByZoneYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyReconectionByZoneYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySummaryByServiceYearMonth" AS
SELECT
    CAST(NULL AS integer) AS "BeforeMonth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "QDegrowth",
    CAST(NULL AS integer) AS "QGrowth",
    CAST(NULL AS integer) AS "QInputs",
    CAST(NULL AS integer) AS "QOutputs",
    CAST(NULL AS integer) AS "QReconnected",
    CAST(NULL AS integer) AS "QStatus",
    CAST(NULL AS integer) AS "QSuspend",
    CAST(NULL AS integer) AS "QTotal",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySummaryByYearMonth" AS
SELECT
    CAST(NULL AS integer) AS "BeforeMonth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "QDegrowth",
    CAST(NULL AS integer) AS "QGrowth",
    CAST(NULL AS integer) AS "QInputs",
    CAST(NULL AS integer) AS "QOutputs",
    CAST(NULL AS integer) AS "QReconnected",
    CAST(NULL AS integer) AS "QStatus",
    CAST(NULL AS integer) AS "QSuspend",
    CAST(NULL AS integer) AS "QTotal",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySummaryByZoneYearMonth" AS
SELECT
    CAST(NULL AS integer) AS "BeforeMonth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "QDegrowth",
    CAST(NULL AS integer) AS "QGrowth",
    CAST(NULL AS integer) AS "QInputs",
    CAST(NULL AS integer) AS "QOutputs",
    CAST(NULL AS integer) AS "QReconnected",
    CAST(NULL AS integer) AS "QStatus",
    CAST(NULL AS integer) AS "QSuspend",
    CAST(NULL AS integer) AS "QTotal",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySummaryByZoneYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "BeforeMonth",
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "QDegrowth",
    CAST(NULL AS integer) AS "QGrowth",
    CAST(NULL AS integer) AS "QInputs",
    CAST(NULL AS integer) AS "QOutputs",
    CAST(NULL AS integer) AS "QReconnected",
    CAST(NULL AS integer) AS "QStatus",
    CAST(NULL AS integer) AS "QSuspend",
    CAST(NULL AS integer) AS "QTotal",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySuspensionByServiceYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySuspensionByServiceYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySuspensionByYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySuspensionByZoneYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanySuspensionByZoneYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyWithdrawalByServiceYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyWithdrawalByServiceYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS integer) AS "Degrowth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdTerms",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS character varying(100)) AS "Term",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyWithdrawalByYearMonth" AS
SELECT
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS integer) AS "Quantity",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyWithdrawalByZoneYearMonth" AS
SELECT
    CAST(NULL AS integer) AS "Degrowth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

CREATE OR REPLACE VIEW "VContractCompanyWithdrawalByZoneYearMonthDay" AS
SELECT
    CAST(NULL AS integer) AS "Day",
    CAST(NULL AS integer) AS "Degrowth",
    CAST(NULL AS uuid) AS "IdCompany",
    CAST(NULL AS integer) AS "IdZone",
    CAST(NULL AS integer) AS "Month",
    CAST(NULL AS character varying(100)) AS "Title",
    CAST(NULL AS integer) AS "Year"
WHERE false;

