-- ============================================================================
-- 03_views.sql  -  Vistas (SAMPLE)
--
-- Las vistas NO llevan datos: se recrean por DDL y quedan FUERA de --validate
-- (el toolkit valida solo tablas base). Se aplican al final.
-- ============================================================================

-- Catalogo: producto + su categoria -----------------------------------------
CREATE VIEW "VProductCatalog" AS
SELECT p."IdProduct",
       p."Sku",
       p."Name"        AS "ProductName",
       c."Name"        AS "CategoryName",
       p."Price",
       p."InStock",
       p."StockQty"
FROM "Product" p
JOIN "Category" c ON c."IdCategory" = p."IdCategory";

-- Totales por cliente --------------------------------------------------------
CREATE VIEW "VCustomerOrderTotals" AS
SELECT cu."IdCustomer",
       cu."FullName",
       cu."Email",
       count(o."IdOrder")            AS "OrderCount",
       COALESCE(sum(o."Total"), 0)   AS "TotalSpent"
FROM "Customer" cu
LEFT JOIN "Order" o ON o."IdCustomer" = cu."IdCustomer"
GROUP BY cu."IdCustomer", cu."FullName", cu."Email";
