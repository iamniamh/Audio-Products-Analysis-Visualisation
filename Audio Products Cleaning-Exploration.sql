SELECT * FROM product_sales;

SELECT * FROM product_data;

SELECT * FROM discount_data;

-- Data Cleaning & Preparation Steps:
-- Remove Duplicates 
-- Standardisation (Format of data, whitespace, typos etc)
-- Address Null and Empty Values
-- Remove useless rows/columns 
-- Combine relevant data

ALTER TABLE product_sales 
RENAME COLUMN Product TO Product_ID;

-- Product_data and Discount Data have only 6 and 16 entries respectively so we can just observe that there's no duplicates. So we only check the Product_Sales table.
-- Using Window Function Row_Number to find any that appear to be duplicates.
WITH cte AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY `Date`, Customer_Type, Country, Product_ID, Discount_Band, Units_Sold, `Month`) AS row_num
FROM product_sales)
SELECT * 
FROM cte
WHERE row_num >1;

-- Only one record has row_num > 1 so we inspect it further 

WITH cte AS(
SELECT *, ROW_NUMBER() OVER(PARTITION BY `Date`, Customer_Type, Country, Product_ID, Discount_Band, Units_Sold, `Month`) AS row_num
FROM product_sales)
SELECT * 
FROM cte
WHERE Country = 'Mexico' AND `Date` = '2022-10-01' AND Customer_Type = 'Government';

-- We can see that on this same day other 'Government' customer type from Mexico made multiple purchases of other products so we can't conclude this is a 
-- duplicate record so we leave it in the table. 
-- Now to standardise the data.

SELECT DISTINCT(country)
FROM product_sales;

SELECT DISTINCT(product_ID)
FROM product_sales;

SELECT DISTINCT(customer_type)
FROM product_sales;

-- Each country, customer_type, product_ID only appears once when selected distinctly (no full stops or typos) so this is fine.
-- We need to remove the dollar signs and convert the prices into number format so we can multiply them later. (They are in text format)
UPDATE product_data
SET Cost_Price = TRIM(LEADING '$' FROM Cost_Price);

UPDATE product_data
SET Sale_Price = TRIM(LEADING '$' FROM Sale_Price);

ALTER TABLE product_data MODIFY Cost_Price DECIMAL(10, 2);

ALTER TABLE product_data MODIFY Sale_Price DECIMAL(10, 2);

-- Now to calculate the actual price the product was sold at (using discount) we need to convert the date column to date format, extract the month and 
-- store it in a separate column, then join the product sales and discount data tables on month and discount band.

UPDATE product_sales
SET `date` = str_to_date(`date`, '%d/%m/%Y');
    
-- We've joined on month but we can't join on Discount_Band yet as they columns are not standardised (One is capitalised, one all lower case)
UPDATE product_sales
SET Discount_Band = LOWER(Discount_Band);

UPDATE product_sales
SET Discount_Band = TRIM(Discount_Band);

UPDATE discount_data
SET Discount_Band = TRIM(Discount_Band);

-- Now adding the Month column to the product sales table
ALTER TABLE product_sales
ADD `Month` text;

UPDATE product_sales
SET `Month` = DATE_FORMAT(`date`, '%M');

-- Now we address null/empty values. We can see by observation there are no null or empty values in product_data or discount data.

SELECT *
FROM product_sales
WHERE (`date` IS NULL) OR (`date` = '')
 OR (customer_type IS NULL) OR (customer_type ='')
 OR (Country IS NULL) OR (Country = '') 
 OR (Product_ID IS NULL) OR (Product_ID = '') 
 OR (Discount_Band IS NULL) OR (Discount_Band = '') 
 OR (Units_Sold IS NULL) OR (Units_Sold = '')
 OR (`Month` IS NULL) OR (`Month` = '');
 
 -- Only one empty value in the product ID column of one record but we still have units sold in that transaction so record isn't completely useless and since the 
 -- Discount_band on that day was 'none we can perhaps populate it with the product ID of the cheapest product the company sells (sale price) as then we know that 
 -- the minimimum amount of money from that transaction rather than taking the sale as 0 but this will be misleading as the cheapest sale price item doesn't 
 -- correspond to the minimum amount of profit so it might mislead the results so I'll just leave it blank
 
-- Finally, create CTE which adds a revenue column, and a total_cost column. We will then create a discounted price column to calculate the actual price the products were sold
-- to the customer using the date of sale and the discount data table.
-- This below is our final combined table what we pass into power BI to make a dashboard. 

WITH cte AS(
SELECT ps.`date`, ps.Customer_Type, ps.Country, 
	ps.Product_ID, ps.Discount_Band, ps.Units_Sold,
    dd.`month`, dd.Discount
FROM product_sales ps
	JOIN discount_data dd
	ON ps.`Month`= dd.`Month` AND ps.Discount_Band = dd.Discount_Band)
SELECT *, 
	ROUND((Sale_Price * Units_Sold), 2) AS revenue, 
    ROUND((Cost_Price * Units_Sold), 2) AS Total_Cost, 
    ROUND(((Sale_Price*Units_Sold) * ((100- Discount)/100) ), 2) AS Paid_Price, 
    ROUND(( ((Sale_Price*Units_Sold) * ((100- Discount)/100) ) - (Cost_Price * Units_Sold)), 2) AS Profit
FROM cte
JOIN product_data AS pd 
	ON cte.Product_ID = pd.Product_ID;