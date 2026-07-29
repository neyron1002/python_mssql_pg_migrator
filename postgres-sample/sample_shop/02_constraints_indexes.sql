-- ============================================================================
-- 02_constraints_indexes.sql  -  PK / FK / indices / colacion (SAMPLE)
--
-- Se aplica DESPUES de 01_schema.sql. Aqui viven las llaves y los indices.
-- El toolkit lee el PK de aqui (via information_schema) para saber por que
-- columna emparejar filas en la paridad de strings.
-- ============================================================================

-- Llaves primarias -----------------------------------------------------------
ALTER TABLE "Category"  ADD CONSTRAINT "PK_Category"  PRIMARY KEY ("IdCategory");
ALTER TABLE "Product"   ADD CONSTRAINT "PK_Product"   PRIMARY KEY ("IdProduct");
ALTER TABLE "Customer"  ADD CONSTRAINT "PK_Customer"  PRIMARY KEY ("IdCustomer");
ALTER TABLE "Order"     ADD CONSTRAINT "PK_Order"     PRIMARY KEY ("IdOrder");
ALTER TABLE "OrderLine" ADD CONSTRAINT "PK_OrderLine" PRIMARY KEY ("IdOrderLine");
ALTER TABLE "ApiToken"  ADD CONSTRAINT "PK_ApiToken"  PRIMARY KEY ("Id");

-- Colacion case-insensitive en el email (analogo *_CI_AS de MSSQL) -----------
ALTER TABLE "Customer" ALTER COLUMN "Email" TYPE varchar(255) COLLATE "sample_ci_as";
ALTER TABLE "Customer" ADD  CONSTRAINT "UQ_Customer_Email" UNIQUE ("Email");
ALTER TABLE "Product"  ADD  CONSTRAINT "UQ_Product_Sku"    UNIQUE ("Sku");

-- Llaves foraneas ------------------------------------------------------------
-- (durante --data el toolkit hace SET session_replication_role = replica, asi
--  que las FK no bloquean el orden de carga; quedan activas despues.)
ALTER TABLE "Product"   ADD CONSTRAINT "FK_Product_Category"
    FOREIGN KEY ("IdCategory") REFERENCES "Category" ("IdCategory");
ALTER TABLE "Order"     ADD CONSTRAINT "FK_Order_Customer"
    FOREIGN KEY ("IdCustomer") REFERENCES "Customer" ("IdCustomer");
ALTER TABLE "OrderLine" ADD CONSTRAINT "FK_OrderLine_Order"
    FOREIGN KEY ("IdOrder")   REFERENCES "Order" ("IdOrder");
ALTER TABLE "OrderLine" ADD CONSTRAINT "FK_OrderLine_Product"
    FOREIGN KEY ("IdProduct") REFERENCES "Product" ("IdProduct");
ALTER TABLE "ApiToken"  ADD CONSTRAINT "FK_ApiToken_Customer"
    FOREIGN KEY ("IdCustomer") REFERENCES "Customer" ("IdCustomer");

-- Indices de apoyo -----------------------------------------------------------
CREATE INDEX "IX_Product_Category"   ON "Product"   ("IdCategory");
CREATE INDEX "IX_Order_Customer"     ON "Order"     ("IdCustomer");
CREATE INDEX "IX_OrderLine_Order"    ON "OrderLine" ("IdOrder");
CREATE INDEX "IX_OrderLine_Product"  ON "OrderLine" ("IdProduct");
CREATE INDEX "IX_ApiToken_Customer"  ON "ApiToken"  ("IdCustomer");
