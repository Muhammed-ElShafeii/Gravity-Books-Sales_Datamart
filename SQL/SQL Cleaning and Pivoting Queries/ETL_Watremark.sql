CREATE TABLE ETL_Watermark (
    table_name   VARCHAR(100),
    last_load_date DATETIME
);

-- Add a row for every table that needs watermark tracking
INSERT INTO ETL_Watermark (table_name, last_load_date) VALUES ('order_history',  '2000-01-01');
INSERT INTO ETL_Watermark (table_name, last_load_date) VALUES ('cust_order',     '2000-01-01');
INSERT INTO ETL_Watermark (table_name, last_load_date) VALUES ('customer',       '2000-01-01');
INSERT INTO ETL_Watermark (table_name, last_load_date) VALUES ('author',         '2000-01-01');
INSERT INTO ETL_Watermark (table_name, last_load_date) VALUES ('book',           '2000-01-01');

SELECT Country_SK, Country_ID_BK, country_name 
FROM Gravity_DWH_2.dbo.Dim_Country

