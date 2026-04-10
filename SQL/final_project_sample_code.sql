/* 1) Identify Top-Tier Vendors, which are those whose total order amounts exceed $100,000
Additionally, show the number of orders we have placed from each vendor. */

SELECT 
    v.BusinessEntityID, 
    v.Name AS VendorName, 
    COUNT(poh.PurchaseOrderID) AS OrderCount,
    SUM(poh.SubTotal) AS TotalOrderAmt
FROM Purchasing.Vendor v
INNER JOIN Purchasing.PurchaseOrderHeader poh 
    ON v.BusinessEntityID = poh.VendorID
GROUP BY v.BusinessEntityID, v.Name
HAVING SUM(poh.SubTotal) > 100000
ORDER BY TotalOrderAmt DESC;


/* 2) Show the amount spent for each Shipping Method, along with the overall total spent on shipping. */

SELECT 
    ISNULL(sm.Name, 'Grand Total') AS ShippingMethod, 
    ROUND(SUM(poh.Freight), 2) AS TotalFreight
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.ShipMethod sm 
    ON poh.ShipMethodID = sm.ShipMethodID
GROUP BY ROLLUP(sm.Name)
ORDER BY sm.Name;


/* 3) Identify and rank the top 10% of products based on their average unit price from actual purchase orders.
Additionally, show the total quantity ordered for each product. */

SELECT TOP 10 PERCENT
    p.Name,
    AVG(pod.UnitPrice) AS AvgUnitPrice,
    SUM(pod.OrderQty) AS TotalQtyOrdered,
    RANK() OVER (ORDER BY AVG(pod.UnitPrice) DESC) AS PriceRank
FROM Production.Product p
INNER JOIN Purchasing.PurchaseOrderDetail pod 
    ON p.ProductID = pod.ProductID
GROUP BY p.Name
ORDER BY AvgUnitPrice DESC;


/* 4) The procurement team wants to know when most purchasing activity happens during the year.
Show the number of orders per month */

SELECT 
    DATENAME(MONTH, poh.OrderDate) AS OrderMonth,
    COUNT(poh.PurchaseOrderID) AS TotalOrders
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.Vendor v
    ON poh.VendorID = v.BusinessEntityID
GROUP BY DATENAME(MONTH, poh.OrderDate), MONTH(poh.OrderDate)
ORDER BY MONTH(poh.OrderDate);


/* 5) A member of the procurement team needs an audit report combining vendor, order date, 
and total amount for each order in a pipe-delimited format */

SELECT 
    poh.PurchaseOrderID,
    CONCAT(
        'Vendor: ', v.Name,
        ' | Date: ', CONVERT(VARCHAR, poh.OrderDate, 23),
        ' | Total: $', ROUND(poh.SubTotal, 2)
    ) AS OrderSummary
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.Vendor v
    ON poh.VendorID = v.BusinessEntityID;


/* 6) Analyze procurement totals and volatility by year to assist with budgeting. */

SELECT 
    YEAR(OrderDate) AS OrderYear, 
    SUM(SubTotal) AS YearlyTotal,
    STDEV(SubTotal) AS SpendVolatility
FROM Purchasing.PurchaseOrderHeader
GROUP BY YEAR(OrderDate)
ORDER BY OrderYear;


/* 7) Identify vendors who have never been used for a purchase order. */

SELECT BusinessEntityID, Name 
FROM Purchasing.Vendor

EXCEPT

SELECT v.BusinessEntityID, v.Name
FROM Purchasing.Vendor v
INNER JOIN Purchasing.PurchaseOrderHeader poh 
    ON v.BusinessEntityID = poh.VendorID;


/* 8) Audit the specific orders and products exceeding our current freight threshold. */
/* NOTE: Be sure to run the variable declaration together with Parts 1 and 2 */

DECLARE @FreightThreshold MONEY = 2500.00;

-- Part 1: General order info for high-freight shipments
SELECT 
    poh.PurchaseOrderID, 
    poh.OrderDate, 
    v.Name, 
    poh.Freight
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.Vendor v
    ON poh.VendorID = v.BusinessEntityID
WHERE poh.Freight > @FreightThreshold;

-- Part 2: Specific products contained within those high-freight orders
SELECT 
    pod.PurchaseOrderID, 
    p.Name AS ProductName, 
    pod.OrderQty, 
    pod.LineTotal
FROM Purchasing.PurchaseOrderDetail pod
INNER JOIN Production.Product p 
    ON pod.ProductID = p.ProductID
WHERE pod.PurchaseOrderID IN (
    SELECT PurchaseOrderID 
    FROM Purchasing.PurchaseOrderHeader 
    WHERE Freight > @FreightThreshold
);


/* 9) Calculate the total spent by product category 
and then identify the categories that exceed the overall average across categories */

WITH CategorySpend AS (
    SELECT 
        pc.Name AS CategoryName,
        SUM(pod.LineTotal) AS TotalCategorySpend
    FROM Purchasing.PurchaseOrderDetail pod
    INNER JOIN Production.Product p 
        ON pod.ProductID = p.ProductID
    INNER JOIN Production.ProductSubcategory ps 
        ON p.ProductSubcategoryID = ps.ProductSubcategoryID
    INNER JOIN Production.ProductCategory pc 
        ON ps.ProductCategoryID = pc.ProductCategoryID
    GROUP BY pc.Name
),
AverageSpend AS (
    SELECT AVG(TotalCategorySpend) AS GlobalCategoryAvg 
    FROM CategorySpend
)
SELECT 
    cs.CategoryName,
    cs.TotalCategorySpend,
    CASE 
        WHEN cs.TotalCategorySpend > (
            SELECT GlobalCategoryAvg 
            FROM AverageSpend
            ) THEN 'Above Average'
        ELSE 'Below Average'
    END AS BudgetStatus
FROM CategorySpend AS cs;


/* 10) Find orders that exceed 3 times the company average to flag for audit. */

SELECT 
    poh.PurchaseOrderID, 
    v.Name AS VendorName,
    poh.SubTotal,
    (SELECT AVG(SubTotal) FROM Purchasing.PurchaseOrderHeader) AS CompanyAvg
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.Vendor v 
    ON poh.VendorID = v.BusinessEntityID
WHERE poh.SubTotal > (
    SELECT AVG(SubTotal) 
    FROM Purchasing.PurchaseOrderHeader
    ) * 3
ORDER BY poh.SubTotal DESC;


/* 11) Shipping costs should never exceed 10% of the order cost. Flag any orders that exceed this threshold.
GOOD NEWS: There are none! */

SELECT 
    PurchaseOrderID, 
    SubTotal,
    Freight,
    (Freight / SubTotal) * 100 AS SurchargePercentage
FROM Purchasing.PurchaseOrderHeader
WHERE Freight / SubTotal > .10
ORDER BY SurchargePercentage DESC;


/* 12) Flag orders where the shipment arrived after the promised date. 
Mark any orders that are > 60 days late as EXTREME DELAY */

SELECT DISTINCT
    poh.PurchaseOrderID, 
    poh.VendorID, 
    poh.OrderDate, 
    pod.DueDate, 
    poh.ShipDate,
    DATEDIFF(day, pod.DueDate, poh.ShipDate) AS DaysLate,
    CASE 
        WHEN DATEDIFF(day, pod.DueDate, poh.ShipDate) > 60 THEN 'EXTREME DELAY'
        ELSE 'LATE'
    END AS ShippingStatus
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.PurchaseOrderDetail pod 
    ON poh.PurchaseOrderID = pod.PurchaseOrderID
WHERE poh.ShipDate > pod.DueDate;


/* 13) Identify vendors and products with high rejection rates (over 5%) */

SELECT 
    v.Name AS VendorName,
    p.Name AS ProductName,
    SUM(pod.ReceivedQty) AS TotalReceived,
    SUM(pod.RejectedQty) AS TotalRejected,
    SUM(pod.RejectedQty) / SUM(pod.ReceivedQty) * 100 AS PercentRejected
FROM Purchasing.PurchaseOrderDetail pod
INNER JOIN Purchasing.PurchaseOrderHeader poh 
    ON pod.PurchaseOrderID = poh.PurchaseOrderID
INNER JOIN Purchasing.Vendor v 
    ON poh.VendorID = v.BusinessEntityID
INNER JOIN Production.Product p 
    ON pod.ProductID = p.ProductID
GROUP BY v.Name, p.Name
HAVING SUM(pod.RejectedQty) > 0 
    AND SUM(pod.RejectedQty) / SUM(pod.ReceivedQty) > 0.05
ORDER BY PercentRejected DESC;


/* 14) The procurement manager is curious about how much we spend on orders for clothing items:
       Cap, Glove, Jersey, Shorts, Socks, Tights, Vest
       NOTE: Gen AI was used for this bonus query (beyond the 12 required) */

DECLARE @SearchList VARCHAR(MAX) = 'Cap,Glove,Jersey,Shorts,Socks,Tights,Vest';

SELECT 
    p.Name AS ProductName, 
    SUM(pod.LineTotal) AS LineItemTotal
FROM Production.Product p
CROSS APPLY STRING_SPLIT(@SearchList, ',') s
INNER JOIN Purchasing.PurchaseOrderDetail pod
    ON p.ProductID = pod.ProductID
WHERE p.Name LIKE '%' + TRIM(s.value) + '%'
GROUP BY p.Name
ORDER BY p.Name;


/* STORED PROCEDURE: The procurement team wants a reusable tool to monitor high-cost purchase orders.
This stored procedure will:
- Accept a minimum order amount as a parameter
- Return all purchase orders above that threshold
- Classify each order as: "High Cost" → if Freight > 10% of SubTotal; "Normal" otherwise */

DROP PROCEDURE IF EXISTS GetHighValuePurchaseOrders;

CREATE PROCEDURE GetHighValuePurchaseOrders
    @MinAmount DECIMAL(18, 2)
AS
BEGIN
    SELECT 
        poh.PurchaseOrderID,
        v.Name AS VendorName,
        poh.OrderDate,
        poh.SubTotal,
        poh.Freight,
        CASE 
            WHEN poh.Freight / NULLIF(poh.SubTotal, 0) > 0.10 
                THEN 'High Cost'
            ELSE 'Normal'
        END AS CostCategory
    FROM Purchasing.PurchaseOrderHeader poh
    INNER JOIN Purchasing.Vendor v
        ON poh.VendorID = v.BusinessEntityID
    WHERE poh.SubTotal >= @MinAmount
    ORDER BY CostCategory DESC;
END;

-- Show the results from the Stored Procedure
EXEC GetHighValuePurchaseOrders @MinAmount = 50000;


/* VIEW: The procurement team needs a centralized dataset to analyze purchasing performance 
without rewriting complex joins every time. This View will:
- Combine purchase orders, vendors, and shipping methods
- Include key financial metrics
- Flag potential cost issues */

DROP VIEW IF EXISTS vw_ProcurementSummary;

CREATE VIEW vw_ProcurementSummary
AS
SELECT 
    poh.PurchaseOrderID,
    poh.OrderDate,
    v.Name AS VendorName,
    sm.Name AS ShipMethod,
    poh.SubTotal,
    poh.Freight,
    (poh.Freight / NULLIF(poh.SubTotal, 0)) * 100 AS FreightPercentage,
    CASE 
        WHEN poh.Freight / NULLIF(poh.SubTotal, 0) > 0.10 
            THEN 'High Freight Cost'
        ELSE 'Normal'
    END AS FreightStatus
FROM Purchasing.PurchaseOrderHeader poh
INNER JOIN Purchasing.Vendor v
    ON poh.VendorID = v.BusinessEntityID
INNER JOIN Purchasing.ShipMethod sm
    ON poh.ShipMethodID = sm.ShipMethodID;

-- Query the view for a quick summary of procurement data:
SELECT * FROM vw_ProcurementSummary;
