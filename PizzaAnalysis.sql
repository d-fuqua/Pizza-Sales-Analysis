-- Initialize Temp Table for Further Queries
-- Creating this temp table makes it so we dont have to do 3 or 4 joins in multiple queries

DROP TABLE IF EXISTS #temp_Full_Pizza_Types
CREATE TABLE #temp_Full_Pizza_Types (
order_id int,
date_time datetime,
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
SELECT ord.order_id, date_time = ord.date + DATEADD(DAY, 2, ord.time), det.order_details_id, det.quantity, piz.pizza_id, piz.size,
	piz.price, pizType.pizza_type_id, pizType.name, pizType.category
FROM PizzaSales.dbo.orders ord
JOIN PizzaSales.dbo.order_details det
	ON ord.order_id = det.order_id
JOIN PizzaSales.dbo.pizzas piz
	ON det.pizza_id = piz.pizza_id
JOIN PizzaSales.dbo.pizza_types pizType
	ON piz.pizza_type_id = pizType.pizza_type_id

SELECT TOP 10 *
FROM #temp_Full_Pizza_Types
ORDER BY order_id

-- Count of Orders per Month
SELECT COUNT(DISTINCT(order_id)) as 'Total Orders', date_time, DATENAME(month, date_time) as 'Month'
FROM #temp_Full_Pizza_Types
GROUP BY date_time, DATENAME(month, date_time)
ORDER BY date_time

-- Average Number of Orders per Hour per Day
SELECT AVG(CountDaily.[Total Orders]) as 'Average Orders', CountDaily.Month
FROM (SELECT COUNT(DISTINCT(order_id)) as 'Total Orders', DATENAME(month, date) as 'Month', DATENAME(DAY, date) as 'Day'
FROM PizzaSales.dbo.orders
GROUP BY DATENAME(month, date), DATENAME(day, date)) as CountDaily
GROUP BY CountDaily.Month
ORDER BY 2

-- Total Sales per Month per Hour
SELECT SUM(price * quantity) as 'Total Sales', DATENAME(month, date_time) as 'Month',
	DATENAME(hour, date_time) as 'Hour'
FROM #temp_Full_Pizza_Types
GROUP BY DATENAME(month, date_time), DATENAME(hour, date_time)

-- Average Sales per Month per Hour
;WITH CTE_AVG_Sales as
(SELECT SUM(quantity * price) as 'Total Sales', DATENAME(month, date_time) as 'Month', DATENAME(day, date_time) as 'Day',
	DATENAME(hour, date_time) as 'Hour'
FROM #temp_Full_Pizza_Types
GROUP BY DATENAME(month, date_time), DATENAME(day, date_time), DATENAME(hour, date_time)
)

SELECT AVG([Total Sales]) as 'Average Sales', Month, Hour
FROM CTE_AVG_Sales
GROUP BY Month, Hour

-- Daily Orders and Sales per Hour per Month
SELECT COUNT(DISTINCT(order_id)) as 'Count of Orders', SUM(price * quantity) as 'Sales',
	DATENAME(month, date_time) as 'Month', DATENAME(day, date_time) as 'Day', DATENAME(hour, date_time) as 'Hour'
FROM #temp_Full_Pizza_Types
GROUP BY DATENAME(month, date_time), DATENAME(day, date_time), DATENAME(hour, date_time)

-- Amount Sold of Each Pizza and Percentage of the Sale
SELECT SUM(quantity) as 'Amount Sold', name, DATEPART(month, date_time) as 'Month', DATEPART(hour, date_time) as 'Hour'
FROM #temp_Full_Pizza_Types
GROUP BY name, DATEPART(month, date_time), DATEPART(hour, date_time)

-- Amount and Percentage of Category over Month and Hour
SELECT category, DATEPART(month, date_time) as 'Month', DATEPART(hour, date_time) as 'Hour', COUNT(category) as 'Amount',
	COUNT(category) * 100.0 / SUM(COUNT(category)) over() as 'Percentage'
FROM #temp_Full_Pizza_Types
GROUP BY category, DATEPART(month, date_time), DATEPART(hour, date_time)

-- Amount and Percentage of Size over Month and Hour
SELECT size, DATEPART(month, date_time) as 'Month', DATEPART(hour, date_time) as 'Hour', COUNT(size) as 'Amount',
	COUNT(size) * 100.0 / SUM(COUNT(size)) over() as 'Percentage'
FROM #temp_Full_Pizza_Types
GROUP BY size, DATEPART(month, date_time), DATEPART(hour, date_time)

-- Percentage of Pizza Sizes on the Top 5 Selling Days
-- Use a subquery in where clause to determine the dates of the top 5 selling days
-- Multiply the count of pizza sizes by 100.0 to get a float and percentage as our output
SELECT size as 'Size', COUNT(size) as 'Total Pizzas',
	(COUNT(size) * 100.0 / SUM(COUNT(size)) over()) as 'Percentage of Size'
FROM #temp_Full_Pizza_Types
WHERE DAY(date_time) IN (SELECT TOP 5 DAY(date_time)
	FROM #temp_Full_Pizza_Types
	GROUP BY DAY(date_time)
	ORDER BY SUM((price * quantity)) DESC)
GROUP BY size

-- Percentage of Category on Top 5 Selling Days
SELECT category as 'Category', COUNT(category) as 'Total Pizza Categories',
	(COUNT(category) * 100.0 / SUM(COUNT(category)) over()) as 'Percentage of Category'
FROM #temp_Full_Pizza_Types
WHERE DAY(date_time) IN (SELECT TOP 5 DAY(date_time)
	FROM #temp_Full_Pizza_Types
	GROUP BY DAY(date_time)
	ORDER BY SUM((price * quantity)) DESC)
GROUP BY category

-- Average Quantity of Pizzas in an Order
SELECT AVG(OrderQuantity.[Total Quantity]) as 'Average Quantity per Order'
FROM (SELECT order_id, SUM(quantity) as 'Total Quantity'
	FROM #temp_Full_Pizza_Types
	GROUP BY order_id) as OrderQuantity

-- Total Quantity Amounts
SELECT quantity, COUNT(quantity) as 'Amount of Quantity',
	COUNT(*) * 100.0 / SUM(COUNT(*)) over() as 'Percentage'
FROM #temp_Full_Pizza_Types
GROUP BY quantity
ORDER BY quantity

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
	FROM (SELECT order_id, MONTH(date_time) as 'MonthNum', DATENAME(month, date_time) as 'MonthName', pizza_id, quantity, price
		FROM #temp_Full_Pizza_Types) as MonthInfo
GROUP BY MonthInfo.MonthNum, MonthInfo.MonthName) as MonthSums
ORDER BY MonthSums.MonthNum

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