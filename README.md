# AdventureWorks Procurement Financial Analysis

## Overview
This project presents a procurement financial analysis of the AdventureWorks database using T-SQL. The objective is to evaluate vendor performance, shipping costs, and procurement trends that may impact the profitability of a bicycle manufacturing and distribution company.

---

## Brief Description
AdventureWorks is a fictitious company specializing in the production and distribution of bicycles. This project provides a comprehensive audit of its purchasing history, focusing on the parts and materials used in manufacturing and resale operations. The analysis evaluates vendor performance and shipping methods to determine their impact on profit margins, while also identifying anomalies in procurement and logistics that may require further investigation.

---

## Objectives
- Identify high-value vendors and procurement concentration
- Analyze shipping costs and their impact on total order value
- Detect anomalies in procurement transactions
- Evaluate supplier performance and delays
- Support data-driven decision-making in procurement operations

---

## Tools & Technologies
- Azure SQL Database
- T-SQL (SQL Server)
- Visual Studio Code
- DBCode (for visualizations)
- GitHub (project repository)

---

## Key Analysis & Queries
The project includes multiple analytical queries covering:

- Vendor performance analysis  
- Shipping cost evaluation  
- Product price ranking  
- Time series analysis of procurement activity  
- Freight anomaly detection  
- Late shipment analysis  
- Rejection rate analysis  

📌 Full SQL script available here:  
👉 [`SQL/final_project_sample_code.sql`](SQL/final_project_sample_code.sql)

---

## Advanced Components

### Stored Procedure
A reusable stored procedure was developed to identify high-value purchase orders and classify them based on freight cost impact.

```sql
EXEC GetHighValuePurchaseOrders @MinAmount = 50000;
```

---

### Views
A centralized view was created to simplify procurement analysis and avoid repetitive joins:

```sql
SELECT * FROM vw_ProcurementSummary;
```

---

## Visualizations

### 1. Procurement Spend by Category
![Category Spend](Visualization/Q4Line.png)

### 2. Monthly Procurement Activity (Time Series)
![Time Series](Visualization/Q9.png)
