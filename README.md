# Gravity-Books-Sales_Datamart
End-to-end Sales Data Mart using SSIS, SSAS, and SQL Server

📌 Overview
This project presents an end-to-end Data Engineering solution for building a Sales Data Mart using the Microsoft Data Platform.
Starting from a raw operational database with significant data quality issues, the solution transforms the data into a clean, structured, and analytics-ready format.
The project includes:
	• Data cleaning and validation using SQL Server
	• ETL pipelines using SQL Server Integration Services (SSIS)
	• Analytical model using SQL Server Analysis Services (SSAS)

🏗️ Project Structure
Gravity_Books_DWH_Project/
 ├── Gravity Books Integration Services   (SSIS Project)
 ├── Gravity_DWH_Analysis                (SSAS Project)
 ├── Database/
 │    └── Gravity_books_v2.bak           (Database Backup)
 └── README.txt
 
⚙️ Requirements
To run this project, the following tools are required:
	• Microsoft SQL Server
	• SQL Server Management Studio (SSMS)
	• Visual Studio / SQL Server Data Tools (SSDT) with SSIS & SSAS extensions

🧹 Data Cleaning & Validation
The source system contained real-world data quality issues such as:
	• Corrupted text values (e.g., ??), mixed languages, and empty strings
	• Duplicate and inconsistent records across multiple tables
	• Invalid relationships and orphaned records
A quarantine table approach was implemented:
	• Invalid records are isolated instead of deleted
	• Each rejected row is labeled with a reject_reason
	• Ensures full auditability and traceability
Final validation checks ensure that only clean and consistent data is loaded into the warehouse.

🏗️ Data Mart Design
The Data Mart follows a Galaxy Schema design with shared dimensions.
Fact Tables
	• Fact_Orders
		○ Grain: one row per order line
		○ Contains sales measures and foreign keys
	• Fact_Order_History_V2
		○ Tracks full order lifecycle
		○ Includes derived metrics such as:
			§ Days Pending
			§ Days to Ship
			§ Days to Deliver
Dimensions
	• Dim_Customer (SCD Type 2)
	• Dim_Book
	• Dim_Author
	• Dim_Country
	• Dim_Language
	• Dim_Shipping_Method
	• Dim_Date
Special Design
	• Bridge table to support many-to-many relationship (Author ↔ Book)

⚙️ ETL Process (SSIS)
The ETL pipeline was developed using SSIS and includes:
	• Incremental loading using an ETL Watermark table
	• SCD Type 1 and Type 2 implementations
	• Lookup transformations for surrogate key resolution
	• Insert and update handling using OLE DB components
	• Master package (Main.dtsx) orchestrating the full workflow

📊 SSAS Analytical Model
A multidimensional cube was built using SSAS to enable fast and flexible analysis.
Features:
	• Measures for revenue, quantities, and order lifecycle KPIs
	• Dimensions for slicing data across time, geography, product, and customer

📈 Business Questions Answered
This Data Mart supports answering key business questions such as:
	• Which books sold the most over time (day, month, quarter, year)?
	• Which authors generate the highest revenue?
	• Which authors perform best by country?
	• Which countries and cities generate the most revenue?
	• Which shipping methods are used most frequently?
	• Which book languages perform best in each country?
	• How long do orders stay pending?
	• How long does it take to ship orders?
	• Which shipping methods cause delays?
	• How many orders are cancelled?
	• What is the average delivery time per country?

🧱 Database Setup
	1. Open SQL Server Management Studio (SSMS)
	2. Right-click on Databases → Restore Database
	3. Select Device and choose:
Gravity_books_v2.bak
	4. Complete the restore process

🔄 Running the ETL
	1. Open the solution file:
Gravity Books Integration Services.sln
	2. Update connection managers if required
	3. Execute the main package:
Main.dtsx

📊 Running the SSAS Cube
	1. Open the SSAS project in Visual Studio
	2. Update the data source connection
	3. Deploy the project to Analysis Services
	4. Process the cube

⚠️ Notes
	• Connection strings may need to be updated based on your local SQL Server instance
	• Ensure SQL Server and SSAS services are running before execution
	• Execute ETL before processing the cube

🎯 Key Learnings
	• Handling real-world data quality issues
	• Designing scalable Data Warehouse schemas
	• Building robust ETL pipelines
	• Creating analytical models for business insights

👨‍💻 Author
Mohamed El Shafei
Data Engineering | Data Analytics | Sales Analytics. 
<img width="843" height="2850" alt="image" src="https://github.com/user-attachments/assets/a9f3f6f2-3f75-4686-aae1-04a261fb985f" />
