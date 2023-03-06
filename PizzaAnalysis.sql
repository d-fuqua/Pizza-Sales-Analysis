-- Initialize Temp Table for Further Queries
-- Creating this temp table makes it so we dont have to do 3 or 4 joins in multiple queries

DROP TABLE IF EXISTS #temp_Full_Pizza_Types
CREATE TABLE #temp_Full_Pizza_Types (
order_id int,
date datetime,
time datetime,
order_details_id int,
quantity int,
pizza_id nvarchar(50),
size nvarchar(50),
price float,
pizza_type_id nvarchar(50),
name nvarchar(50),
category nvarchar(50)
)

INSERT INTO #temp_Full_Pizza_Types
SELECT ord.order_id, ord.date, ord.time, det.order_details_id, det.quantity, piz.pizza_id, piz.size,
	piz.price, pizType.pizza_type_id, pizType.name, pizType.category
FROM PizzaSales.dbo.orders ord
JOIN PizzaSales.dbo.order_details det
	ON ord.order_id = det.order_id
JOIN PizzaSales.dbo.pizzas piz
	ON det.pizza_id = piz.pizza_id
JOIN PizzaSales.dbo.pizza_types pizType
	ON piz.pizza_type_id = pizType.pizza_type_id

SELECT *
FROM #temp_Full_Pizza_Types
ORDER BY order_id

-- Total Number of Orders
SELECT COUNT(order_id) as 'Total Orders'
FROM PizzaSales.dbo.orders

-- Number of Orders MTD
-- Can replace the dates in the WHERE clause to get WTD and YTD orders
SELECT COUNT(order_id) as 'Total Orders MTD'
FROM PizzaSales.dbo.orders
WHERE date BETWEEN '12-01-2015' AND '12-31-2015'

-- Count of Orders by Month
SELECT MONTH(date) as 'Month Num', DATENAME(Month, date) as 'Month Name', COUNT(order_id) as 'Total Orders'
FROM PizzaSales.dbo.orders
GROUP BY MONTH(date), DATENAME(Month, date)
ORDER BY 1

-- Total Money Made
SELECT SUM(price * quantity) as 'Total Money Made'
FROM #temp_Full_Pizza_Types

-- Average Price per Order
;WITH CTE_AVG_Price as
(SELECT SUM(quantity) as 'Total_Quantity', SUM(price * quantity) as 'Total_Price'
FROM #temp_Full_Pizza_Types
)

SELECT Total_Price / Total_Quantity as 'Avg Price per Order'
FROM CTE_AVG_Price

-- Average Orders per Day
SELECT DailySales.Day, AVG(DailySales.[Order Count]) as 'Average Daily Orders'
FROM (SELECT DATENAME(WEEKDAY, ord.date) as 'Day', DATEPART(Week, ord.date) as 'Week #', COUNT(ord.order_id) as 'Order Count'
	FROM PizzaSales.dbo.orders ord
	GROUP BY DATENAME(WEEKDAY, ord.date), DATEPART(Week, ord.date)) as DailySales
GROUP BY DailySales.Day
ORDER BY 2 DESC

-- Top 5 Highest Selling Days
SELECT TOP 5 date, SUM((price * quantity)) as 'Total Sales', SUM(quantity) as 'Quantity Sold'
FROM #temp_Full_Pizza_Types
GROUP BY date
ORDER BY SUM((price * quantity)) DESC

-- Percentage of Pizza Sizes on the Top 5 Selling Days
-- Use a subquery in where clause to determine the dates of the top 5 selling days
-- Multiply the count of pizza sizes by 100.0 to get a float and percentage as our output
SELECT size as 'Size', COUNT(size) as 'Total Pizzas',
	(COUNT(size) * 100.0 / SUM(COUNT(size)) over()) as 'Percentage of Size'
FROM #temp_Full_Pizza_Types
WHERE date IN (SELECT TOP 5 date
	FROM #temp_Full_Pizza_Types
	GROUP BY date
	ORDER BY SUM((price * quantity)) DESC)
GROUP BY size

-- Percentage of Category on Top 5 Selling Days
SELECT category as 'Category', COUNT(category) as 'Total Pizza Categories',
	(COUNT(category) * 100.0 / SUM(COUNT(category)) over()) as 'Percentage of Category'
FROM #temp_Full_Pizza_Types
WHERE date IN (SELECT TOP 5 date
	FROM #temp_Full_Pizza_Types
	GROUP BY date
	ORDER BY SUM((price * quantity)) DESC)
GROUP BY category

-- Most Popular Pizza MTD
-- Can change the date in the WHERE clause like the # of orders MTD
SELECT DISTINCT(SUM(quantity) OVER(PARTITION BY name)) as 'Quantity Sold', name, category
FROM #temp_Full_Pizza_Types
WHERE date BETWEEN '12-01-2015' AND '12-31-2015'
ORDER BY 1 DESC

-- Count and Percentage of Category
SELECT category, COUNT(category) as 'Amount',
	COUNT(category) * 100.0 / SUM(COUNT(category)) over() as 'Percentage'
FROM #temp_Full_Pizza_Types
GROUP BY category

-- Count and Percentage of Size
SELECT size, COUNT(size) as 'Amount',
	COUNT(size) * 100.0 / SUM(COUNT(size)) over() as 'Percentage'
FROM #temp_Full_Pizza_Types
GROUP BY size

-- Count and Percentage of Category AND Size
SELECT category, size, COUNT(*) as 'Amount of Category and Size',
	COUNT(*) * 100.0 / SUM(COUNT(*)) over() as 'Percentage'
FROM #temp_Full_Pizza_Types
GROUP BY category, size
ORDER BY 3 DESC

-- Average Quantity of Pizzas in an Order
SELECT AVG(OrderQuantity.[Total Quantity]) as 'Average Quantity per Order'
FROM (SELECT ord.order_id, SUM(det.quantity) as 'Total Quantity'
	FROM PizzaSales.dbo.orders ord
	JOIN PizzaSales.dbo.order_details det
		ON ord.order_id = det.order_id
	GROUP BY ord.order_id) as OrderQuantity

-- Total Quantity Amounts
SELECT det.quantity, COUNT(det.quantity) as 'Amount of Quantity',
	COUNT(*) * 100.0 / SUM(COUNT(*)) over() as 'Percentage'
FROM PizzaSales.dbo.orders ord
JOIN PizzaSales.dbo.order_details det
	ON ord.order_id = det.order_id
GROUP BY det.quantity
ORDER BY det.quantity

-- Average Price per Category
SELECT category, AVG(price) as 'Average Price'
FROM #temp_Full_Pizza_Types
GROUP BY category

-- Top 3 Pizzas per Category
SELECT pizInfo.name, pizInfo.category, pizInfo.[Sum of Quantity] as 'Quantity Sold'
FROM (SELECT name, category, SUM(quantity) as 'Sum of Quantity',
		RANK() OVER(PARTITION BY category ORDER BY SUM(quantity) DESC) as 'Rank'
	FROM #temp_Full_Pizza_Types
	GROUP BY category, name
) as pizInfo
WHERE pizInfo.Rank <= 3

-- Money Made per Month vs. Total Money Made (Rolling Total)
SELECT MonthSums.MonthNum, MonthSums.MonthName, MonthSums.[Sum of Sales],
	SUM(MonthSums.[Sum of Sales]) OVER (ORDER BY MonthSums.MonthNum) as 'Running Total'
FROM (SELECT MonthInfo.MonthNum, MonthInfo.MonthName, SUM(MonthInfo.quantity * MonthInfo.price) as 'Sum of Sales'
	FROM (SELECT order_id, MONTH(date) as 'MonthNum', DATENAME(month, date) as 'MonthName', pizza_id, quantity, price
		FROM #temp_Full_Pizza_Types) as MonthInfo
GROUP BY MonthInfo.MonthNum, MonthInfo.MonthName) as MonthSums
ORDER BY MonthSums.MonthNum

-- Count of Orders and Number of Pizzas Sold by Week
SELECT DATEPART(week, ord.date) as 'Week', COUNT(ord.order_id) as 'Count of Orders', SUM(det.quantity) as 'Pizzas Sold'
FROM PizzaSales.dbo.orders ord
JOIN PizzaSales.dbo.order_details det
	ON ord.order_id = det.order_id
GROUP BY DATEPART(week, ord.date)
ORDER BY DATEPART(week, ord.date) ASC

-- Money Made by Week
SELECT DATEPART(week, date) as 'Week', SUM(quantity * price) as 'Money Made'
FROM #temp_Full_Pizza_Types
GROUP BY DATEPART(week, date)
ORDER BY DATEPART(week, date)

-- Count Orders per Hour
SELECT DATEPART(hour, time) as 'Hour', COUNT(order_id) as 'Count of Orders'
FROM PizzaSales.dbo.orders
GROUP BY DATEPART(hour, time)
ORDER BY 1

-- Average Orders per Hour per Day
SELECT DailyHourlySales.Day, DailyHourlySales.Hour, AVG(DailyHourlySales.[Order Count]) as 'Average Orders per Hour'
FROM (SELECT DATENAME(WEEKDAY, ord.date) as 'Day', DATEPART(Week, ord.date) as 'Week #', DATEPART(hour, ord.time) as 'Hour', 
	COUNT(ord.order_id) as 'Order Count'
	FROM PizzaSales.dbo.orders ord
	GROUP BY DATENAME(WEEKDAY, ord.date), DATEPART(Week, ord.date), DATEPART(hour, ord.time)) as DailyHourlySales
GROUP BY DailyHourlySales.Day, DailyHourlySales.Hour
ORDER BY 1, 2