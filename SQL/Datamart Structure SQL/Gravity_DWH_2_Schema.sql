-- ============================================================
--  Gravity_DWH_2 — Sales Data Mart Schema
--  Author: Mohamed El Shafei
--  Description: Full DDL for all dimension and fact tables
--               in the Gravity Books Sales Data Mart
-- ============================================================

USE Gravity_DWH_2;
GO

-- ============================================================
-- DIM_DATE
-- Static date dimension
-- Key format: YYYYMMDD integer (e.g. 20200101)
-- Sentinel row SK = 19000101 used for NULL / not-yet-reached dates
-- ============================================================
CREATE TABLE Dim_Date (
    Date_SK         INT           NOT NULL,
    [Date]          DATE          NOT NULL,
    [Day]           TINYINT       NOT NULL,
    DayOfWeek       TINYINT       NOT NULL,
    DayName         VARCHAR(10)   NOT NULL,
    DayOfYear       SMALLINT      NOT NULL,
    WeekOfYear      TINYINT       NOT NULL,
    [Month]         TINYINT       NOT NULL,
    MonthName       VARCHAR(10)   NOT NULL,
    Quarter         TINYINT       NOT NULL,
    QuarterName     VARCHAR(6)    NOT NULL,
    [Year]          SMALLINT      NOT NULL,
    IsWeekend       BIT           NOT NULL DEFAULT 0,
    IsHoliday       BIT           NOT NULL DEFAULT 0,
    HolidayName     VARCHAR(100)  NULL,
    CONSTRAINT PK_Dim_Date PRIMARY KEY (Date_SK)
);
GO

-- Sentinel row for NULL dates (e.g. order not yet delivered)
INSERT INTO Dim_Date (Date_SK, [Date], [Day], DayOfWeek, DayName, DayOfYear,
                      WeekOfYear, [Month], MonthName, Quarter, QuarterName, [Year])
VALUES (19000101, '1900-01-01', 1, 2, 'Monday', 1, 1, 1, 'January', 1, 'Q1', 1900);
GO

-- ============================================================
-- DIM_COUNTRY
-- ============================================================
CREATE TABLE Dim_Country (
    Country_SK      INT           NOT NULL IDENTITY(1,1),
    Country_ID      INT           NOT NULL,
    Country_Name    VARCHAR(200)  NOT NULL,
    CONSTRAINT PK_Dim_Country PRIMARY KEY (Country_SK),
    CONSTRAINT UQ_Dim_Country_BK UNIQUE (Country_ID)
);
GO

-- ============================================================
-- DIM_LANGUAGE
-- ============================================================
CREATE TABLE Dim_Language (
    Language_SK     INT           NOT NULL IDENTITY(1,1),
    language_id     INT           NOT NULL,
    language_name   VARCHAR(100)  NOT NULL,
    language_code   VARCHAR(8)    NULL,
    CONSTRAINT PK_Dim_Language PRIMARY KEY (Language_SK),
    CONSTRAINT UQ_Dim_Language_BK UNIQUE (language_id)
);
GO

-- ============================================================
-- DIM_SHIPPING_METHOD
-- ============================================================
CREATE TABLE Dim_Shipping_Method (
    Shipping_SK         INT           NOT NULL IDENTITY(1,1),
    shipping_method_id  INT           NOT NULL,
    Method_ID           INT           NULL,
    Method_Name         VARCHAR(100)  NOT NULL,
    CONSTRAINT PK_Dim_Shipping PRIMARY KEY (Shipping_SK),
    CONSTRAINT UQ_Dim_Shipping_BK UNIQUE (shipping_method_id)
);
GO

-- ============================================================
-- DIM_AUTHOR
-- ============================================================
CREATE TABLE Dim_Author (
    Author_SK       INT           NOT NULL IDENTITY(1,1),
    Author_ID_BK    INT           NOT NULL,
    Author_name     VARCHAR(300)  NOT NULL,
    CONSTRAINT PK_Dim_Author PRIMARY KEY (Author_SK),
    CONSTRAINT UQ_Dim_Author_BK UNIQUE (Author_ID_BK)
);
GO

-- ============================================================
-- DIM_BOOK
-- ============================================================
CREATE TABLE Dim_Book (
    Book_SK         INT           NOT NULL IDENTITY(1,1),
    Book_ID_BK      INT           NOT NULL,
    Title           VARCHAR(500)  NOT NULL,
    ISBN13          VARCHAR(20)   NULL,
    Language_SK     INT           NULL,
    PublicationDate DATE          NULL,
    CONSTRAINT PK_Dim_Book PRIMARY KEY (Book_SK),
    CONSTRAINT UQ_Dim_Book_BK UNIQUE (Book_ID_BK),
    CONSTRAINT FK_Dim_Book_Language FOREIGN KEY (Language_SK)
        REFERENCES Dim_Language (Language_SK)
);
GO


-- ============================================================
-- DIM_CUSTOMER_V3
-- SCD Type 2 — tracks address/status history
-- Current record:    End_Date IS NULL
-- Historical record: End_Date has a value
-- ============================================================
CREATE TABLE Dim_Customer_V3 (
    customer_sk     INT           NOT NULL IDENTITY(1,1),
    customer_id     INT           NOT NULL,
    first_name      VARCHAR(100)  NULL,
    last_name       VARCHAR(100)  NULL,
    email           VARCHAR(200)  NULL,
    address_id      INT           NULL,
    street_number   VARCHAR(20)   NULL,
    street_name     VARCHAR(200)  NULL,
    city            VARCHAR(100)  NULL,
    Country_SK      INT           NULL,
    status_id       INT           NULL,
    Start_Date      DATETIME      NOT NULL,
    End_Date        DATETIME      NULL,       -- NULL = current active record
    CONSTRAINT PK_Dim_Customer PRIMARY KEY (customer_sk),
    CONSTRAINT FK_Dim_Customer_Country FOREIGN KEY (Country_SK)
        REFERENCES Dim_Country (Country_SK)
);
GO

-- ============================================================
-- AUTHOR_BOOK BRIDGE TABLE
-- Resolves many-to-many between Dim_Author and Dim_Book
-- ============================================================
CREATE TABLE Author_Book (
    Book_SK         INT           NOT NULL,
    Author_SK       INT           NOT NULL,
    Author_ID       INT           NULL,
    CONSTRAINT PK_Author_Book PRIMARY KEY (Book_SK, Author_SK),
    CONSTRAINT FK_Bridge_Book   FOREIGN KEY (Book_SK)   REFERENCES Dim_Book   (Book_SK),
    CONSTRAINT FK_Bridge_Author FOREIGN KEY (Author_SK) REFERENCES Dim_Author (Author_SK)
);
GO

-- ============================================================
-- FACT_ORDER_HISTORY_V2
-- Grain: one row per order
-- Pivoted status lifecycle with one date SK per phase
-- Sentinel SK = 19000101 when a phase was never reached
-- ============================================================
CREATE TABLE Fact_Order_History_V2 (
    History_SK              INT           NOT NULL IDENTITY(1,1),
    History_ID_BK           INT           NULL,
    Order_ID                INT           NOT NULL,
    customer_sk             INT           NULL,
    Shipping_SK             INT           NULL,
    Order_Received_SK_KEY   INT           NOT NULL DEFAULT 19000101,
    Pending_Delivery_SK_KEY INT           NOT NULL DEFAULT 19000101,
    In_Progress_SK_KEY      INT           NOT NULL DEFAULT 19000101,
    Delivered_SK_KEY        INT           NOT NULL DEFAULT 19000101,
    Cancelled_SK_KEY        INT           NOT NULL DEFAULT 19000101,
    Returned_SK_KEY         INT           NOT NULL DEFAULT 19000101,
    Days_Pending            INT           NULL,
    Days_to_Ship            INT           NULL,
    Days_to_Deliver         INT           NULL,
    Total_Order_Days        INT           NULL,
    Current_Status          VARCHAR(50)   NULL,
    Is_Cancelled            BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_Fact_Order_History PRIMARY KEY (History_SK),
    CONSTRAINT FK_FOH_Customer  FOREIGN KEY (customer_sk)             REFERENCES Dim_Customer_V3   (customer_sk),
    CONSTRAINT FK_FOH_Shipping  FOREIGN KEY (Shipping_SK)             REFERENCES Dim_Shipping_Method (Shipping_SK),
    CONSTRAINT FK_FOH_Date_Rcv  FOREIGN KEY (Order_Received_SK_KEY)   REFERENCES Dim_Date (Date_SK),
    CONSTRAINT FK_FOH_Date_Pnd  FOREIGN KEY (Pending_Delivery_SK_KEY) REFERENCES Dim_Date (Date_SK),
    CONSTRAINT FK_FOH_Date_Prg  FOREIGN KEY (In_Progress_SK_KEY)      REFERENCES Dim_Date (Date_SK),
    CONSTRAINT FK_FOH_Date_Dlv  FOREIGN KEY (Delivered_SK_KEY)        REFERENCES Dim_Date (Date_SK),
    CONSTRAINT FK_FOH_Date_Cnl  FOREIGN KEY (Cancelled_SK_KEY)        REFERENCES Dim_Date (Date_SK),
    CONSTRAINT FK_FOH_Date_Ret  FOREIGN KEY (Returned_SK_KEY)         REFERENCES Dim_Date (Date_SK)
);
GO

-- ============================================================
-- FACT_ORDERS_V3
-- Grain: one row per order line (book purchased per order)
-- ============================================================
CREATE TABLE Fact_Orders_V3 (
    Line_SK         INT             NOT NULL IDENTITY(1,1),
    Order_ID        INT             NOT NULL,
    Book_SK         INT             NOT NULL,
    customer_sk     INT             NULL,
    Shipping_SK     INT             NULL,
    Date_SK         INT             NOT NULL,
    Price           DECIMAL(10,2)   NULL,
    Country         VARCHAR(200)    NULL,
    CONSTRAINT PK_Fact_Orders PRIMARY KEY (Line_SK),
    CONSTRAINT FK_FO_Book     FOREIGN KEY (Book_SK)     REFERENCES Dim_Book            (Book_SK),
    CONSTRAINT FK_FO_Customer FOREIGN KEY (customer_sk) REFERENCES Dim_Customer_V3     (customer_sk),
    CONSTRAINT FK_FO_Shipping FOREIGN KEY (Shipping_SK) REFERENCES Dim_Shipping_Method (Shipping_SK),
    CONSTRAINT FK_FO_Date     FOREIGN KEY (Date_SK)     REFERENCES Dim_Date            (Date_SK)
);
GO

-- ============================================================
-- END OF SCHEMA SCRIPT
-- ============================================================
