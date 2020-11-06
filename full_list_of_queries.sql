--query 1
SELECT AVG(Price) AS Average_Price
FROM price_history Ph
-- straightforward condition if price history record's start and end date lie  completely in August
WHERE Ph.PName = 'iPhone XS' AND ( (Ph.End_date >= '2020-08-01 00:00:00.000' AND Ph.End_date <= '2020-08-31 23:59:59.999')
-- if August is a subset of the start_date and end_date of the price_history record
OR (Ph.Starting_date <= '2020-08-01 00:00:00.000' AND (Ph.End_date is NULL OR Ph.End_date >= '2020-08-01 00:00:00.000')));
-- If end_date is NULL, it means that until present time the product in a shop has that particular price

--query 2
SELECT PName, AVG(CAST(Rating as Float)) AS Average_Rating
FROM feedback
WHERE PName IN (SELECT Pname FROM feedback WHERE Rating = 5 AND
Date_time >= '2020-08-01 00:00:00.000' AND Date_time <= '2020-08-31 23:59:59.999' 
GROUP BY Pname
HAVING COUNT(*) >= 100)
GROUP BY PName
ORDER BY AVG(CAST(Rating as Float));

--query 3
SELECT PName, AVG(CAST( DateDiff(s, Orders.Date_time, Products_in_orders.delivery_date) AS Float)) / (3600*24) AS Average_Num_Days_For_Delivery
FROM products_in_orders, orders
WHERE products_in_orders.oid = orders.oid
AND orders.Date_time <= '2020-06-30 23:59:59.999'
AND orders.Date_time >= '2020-06-01 00:00:00.000'
AND products_in_orders.delivery_date IS NOT NULL
GROUP BY PName;

--query 4
WITH LatencyTable AS
(
   -- date arithmetic up to second precision and represented as days
   SELECT complaints.eid, AVG(CAST( DateDiff(s, complaints.Filled_date_time, complaints.Handled_date_time) AS Float)) / (3600*24) AS Lowest_Latency_days
   FROM complaints
   WHERE complaints.Handled_date_time is NOT NULL
   GROUP BY complaints.eid
)
-- select the employee(s) with the lowest latency
SELECT employees.eid, employees.EName, LatencyTable.Lowest_Latency_days
FROM LatencyTable, employees
WHERE LatencyTable.EID = employees.EID AND Lowest_Latency_days
IN (SELECT MIN(Lowest_Latency_days) FROM LatencyTable);

-- query 5
-- create a temporary table to track latency when handling complaints for each employee
-- For each product by Samsung, display the number of shops selling them
SELECT PIS.PName, COUNT(SName) AS Shops_selling
FROM products_in_shops PIS,products P
WHERE P.Maker='Samsung' AND P.PName = PIS.PName
GROUP BY PIS.PName;


--query 6
WITH RevenueTable AS
(SELECT products_in_orders.SName, SUM(products_in_orders.Price*products_in_orders.Qty) AS Total_Revenue
FROM products_in_orders
INNER JOIN ORDERS
ON products_in_orders.OID = ORDERS.OID
WHERE orders.Date_time >= '2020-08-01 00:00:00.000' AND orders.Date_time <= '2020-08-31 23:59:59.999' AND product_status <>'Returned'
GROUP BY SName)
SELECT RevenueTable.SName, RevenueTable.Total_Revenue
FROM RevenueTable
WHERE Total_Revenue IN (SELECT MAX(Total_Revenue) FROM RevenueTable)


--query 7
-- number of complaints by each user
with UsersNumComplaints AS 
(
    SELECT complaints.UserID, COUNT(CID) AS complaints_made 
    FROM complaints 
    GROUP BY complaints.UserID
),
 
-- get the orders for users making the most complaint
OrdersofUsersWithMostComplaints AS
(
    SELECT om.UserID,OID 
    FROM UsersNumComplaints AS om, orders
    WHERE
    om.UserID = orders.UserID
    AND om.complaints_made IN (
        SELECT MAX(complaints_made) FROM UsersNumComplaints
    ) 
 
),
 
-- get the name and price for products placed by users with most complaints
ProdBoughtByUser AS 
(
    SELECT users.UserID, users.UName, PName, Price
    FROM products_in_orders AS PIO, users, OrdersOfUsersWithMostComplaints
    WHERE PIO.OID = OrdersOfUsersWithMostComplaints.OID AND OrdersOfUsersWithMostComplaints.UserID = users.UserID
),
 
-- get the most expensive price for products placed by each users with most complaints 
HighestPriceByUser AS 
(
    SELECT UserID, MAX(Price) AS Highest_Price
    FROM ProdBoughtByUser
    GROUP BY UserID
)
 
-- get the name and price for most expensive products placed by users
SELECT ProdBoughtByUser.userID, ProdBoughtByUser.UName, ProdBoughtByUser.PName, ProdBoughtByUser.Price
FROM ProdBoughtByUser,HighestPriceByUser
WHERE ProdBoughtByUser.userID = HighestPriceByUser.UserID AND ProdBoughtByUser.Price = HighestPriceByUser.Highest_Price;

--query 8

WITH Product_User_Ordered AS
(
           SELECT PName, COUNT(DISTINCT orders.UserID) AS User_Ordered FROM products_in_orders, orders
           WHERE products_in_orders.oid = orders.OID 
           GROUP BY products_in_orders.PName, orders.UserID
),
Products_Order_Count AS
(
           SELECT PName, SUM(User_Ordered) AS Total_Orders FROM Product_User_Ordered GROUP BY PName
),
Required_products AS
(
    SELECT PName FROM Products_Order_Count WHERE Total_Orders NOT IN
  (
           SELECT COUNT(UserID) FROM users
  )
),
Aug_Prod_count AS
(
    SELECT PName, COUNT(*) AS Prod_num 
    FROM products_in_orders, orders
    WHERE products_in_orders.oid = orders.OID AND orders.Date_time >= '2020-08-01 00:00:00.000' AND Date_time <= '2020-08-31 23:59:59.999'
    GROUP BY PName
)
SELECT TOP 5 PName, Prod_num
FROM Aug_Prod_count
WHERE Pname in (SELECT PName from Required_Products)
ORDER BY Prod_num DESC;

--query 9
-- a temporary table to record monthly sales for products, noting down the month and year of each month
WITH MonthlySalesForProducts AS
(SELECT PName, MONTH(Date_time) AS purchased_month, YEAR(Date_time) AS purchased_year, SUM(Qty) AS MonthlyQuantity
FROM orders o, products_in_orders pio
WHERE o.OID = pio.OID
GROUP BY pio.PName,YEAR(Date_time) ,MONTH(Date_time))
 
SELECT DISTINCT t1.PName FROM
MonthlySalesForProducts t1, MonthlySalesForProducts t2, MonthlySalesForProducts t3
-- join by PName
WHERE t1.Pname = t2.PName AND t2.PName = t3.PName
-- increasing sales
AND t1.MonthlyQuantity < t2.MonthlyQuantity AND t2.MonthlyQuantity < t3.MonthlyQuantity
 
-- 2 possible cases for the 3 months, consecutive months in the same year or different year
AND (
   -- for all months in the same year, increasing sales for 3 consecutive months in the same year
      (
       t1.purchased_year = t2.purchased_year AND t2.purchased_year = t3.purchased_year
       AND t1.purchased_month + 1= t2.purchased_month AND t2.purchased_month + 1 = t3.purchased_month
      )
   -- for end of months cases with different years, eg: dec 2020, jan 2021, feb 2021
   OR (
       -- ensure consecutive months
       ((t1.purchased_month + 1)%12 = (t2.purchased_month % 12) AND (t2.purchased_month + 1) % 12 = t3.purchased_month % 12)
      
       -- year can only differ by 1, and if t2 is in the next year t3 must be in the next year, else only t3 is in the next year
       AND (
           (t2.purchased_year = t3.purchased_year AND t1.purchased_year +1 = t2.purchased_year)
           OR
           (t1.purchased_year = t2.purchased_year AND t3.purchased_year + 1 = t2.purchased_year)
           )
       )
   )
