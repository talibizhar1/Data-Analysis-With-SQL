CREATE DATABASE csip;
USE csip;
/***********************************Loading Dataset****************************************/
-- Creating customer table and assigning data types
CREATE TABLE customers(
customer_id CHAR(8),
cust_name  VARCHAR(30),
gender CHAR(6),
age INT );
-- Loading data file
LOAD DATA INFILE   'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Csip/customer_dataset1.csv'
INTO TABLE customers 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Creating product table
CREATE TABLE products(
product_id CHAR(15),
product_name  VARCHAR(150),
category VARCHAR(30),
price FLOAT ) ;

-- Loading procuct table 
LOAD DATA INFILE   'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Csip/product_dataset3.csv'
INTO TABLE products 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Creating sales table
CREATE TABLE sales(
transaction_id CHAR(14) ,
customer_id  CHAR(8) ,
product_id CHAR(15),
`date` DATE,
quantity varchar(10),
amount INT);
/*At the time of importing I was getting incorrect integer error for 'qauntity column' it might be possible that this column contain
values other than numbers including empty values, so I'll simply load it as character then clean and modify it after*/
-- Loading sales data file
LOAD DATA INFILE   'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Csip/sales_dataset3.csv'
INTO TABLE sales 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(transaction_id, customer_id, product_id, @`date`, quantity, amount)
set `date` =str_to_date(@`date`, '%d-%m-%Y');
/*since date format in original file is date-month-year, so I specified the format at the time of import by using function*/
-- Creating inventory table
CREATE TABLE inventory(
product_id CHAR(15) ,
stock INT );
-- Loading dataset
LOAD DATA INFILE   'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Csip/inventory_dataset1.csv'
INTO TABLE inventory 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

/*************************Task 1: Data Exploration and Cleaning*************************/
-- 1. Load the dataset into a SQL database and examine its structure.
-- Data has been loaded, now I'll examine the structure
-- structure of customers table
/*DESC customers;/* 4 rows returned that means there are 4 columns in this table. This query also tells the data type and constraints on columns*/
SELECT COUNT(*) number_of_rows,   'customer_table' as 'table' from customers  /*804 rows*/
UNION ALL
-- structure of products table
/*desc products; /* 4 columns*/
SELECT COUNT(*) , 'product_table' from products /*10194 rows*/
UNION ALL
-- structure of sales table
/*desc sales;  6 columns*/
SELECT COUNT(*), 'sales_table' from sales   /*5111 rows*/
UNION ALL
-- structure of inventory table
/*desc inventory;  2 columns*/
SELECT COUNT(*), 'inventory_table' from inventory   ; /*1862 rows*/

-- 2. Identify and handle missing values appropriately (e.g., remove rows, impute values).
-- First I'll check if the uniquely identified columns are unique and not null 
SELECT 
(SELECT COUNT(DISTINCT customer_id) from customers) as unique_customerids,
(SELECT COUNT(DISTINCT product_id) from products) as unique_productids,
(SELECT COUNT(DISTINCT transaction_id) from sales) as unique_trxnids,
(SELECT COUNT(DISTINCT product_id) from inventory) as unique_productids;
/*customer id has 804 rows, product id has 10194 rows, transaction id has 5111 and inventory 1862. Mismatch in rows for product table
It means there are Duplicates in product table*/

-- Removing Duplicates from Product table
-- First identifying how many duplicates are present for each product_id
SELECT product_id, count(*) same_product_id from products group by product_id having same_product_id>1;
-- Varying number of dupliacates, now identifying the duplicate rows
WITH cte as (
SELECT *, ROw_NUMBER() OVER(PARTITION BY  product_id) same_product_id FROM products)
SELECT * FROM cte WHERE same_product_id>1;

-- Adding an autoincrement column that is unique for each row
ALTER TABLE products
ADD COLUMN r_no INT AUTO_INCREMENT KEY FIRST;

DELETE FROM products
WHERE r_no IN (
SELECT r_no
	   FROM (SELECT r_no, ROw_NUMBER() OVER(PARTITION BY  product_id ORDER BY price DESC) same_product_id FROM products) d
 WHERE same_product_id>1
 );
/*1862 rows left in product table*/
SELECT* FROM products where product_id ='FUR-BO-10000468' ; 
 
 -- CHECKING MISSING OR NULL VALUES 
-- Customer table
SELECT count(*) FROM customers WHERE age IS NULL OR age=' '
OR customer_id IS NULL OR customer_id =''
OR cust_name IS NULL OR cust_name=''
OR gender IS NULL OR gender = '';
-- No null values found in customer table

-- Product table
SELECT  count(*) FROM products 
WHERE product_id IS NULL OR product_id = ''
OR product_name IS NULL OR product_name = ''
OR category IS NULL OR category = ''
OR price IS NULL OR price = '';
-- No null or blank values

-- Sales Table
SELECT  count(*) FROM sales 
WHERE transaction_id IS NULL OR transaction_id = ''
OR customer_id IS NULL OR customer_id = ''
OR product_id IS NULL OR product_id = ''
OR `date` IS NULL 
OR quantity IS NULL OR quantity = ''
OR amount IS NULL OR amount = '';
-- 15 records with empty or null values, I'll check which column they belong to
SELECT  * FROM sales 
WHERE transaction_id IS NULL OR transaction_id = ''
OR customer_id IS NULL OR customer_id = ''
OR product_id IS NULL OR product_id = ''
OR `date` IS NULL 
OR quantity IS NULL OR quantity = ''
OR amount IS NULL OR amount = '';
/*Some product id and quantity are missing in this case I'll replace the quantity with mean
and remove the product_id as there are only 3 missing records.
quantity column is in chatacter data type, so I'll check for any inconsistencies like alphabets, special characters present in column*/
SELECT quantity FROM sales 
WHERE quantity  NOT REGEXP  '[0-9]'; /*REGEXP to find pattern, here to show every characters excluding numbers*/
-- No alphabet or special characters found

-- Inventory Table
SELECT  COUNT(*) FROM inventory 
WHERE product_id IS NULL OR product_id = ''
OR stock IS NULL OR stock = '';
-- 15 records found, checking the records
SELECT  * FROM inventory 
WHERE product_id IS NULL OR product_id = ''
OR stock IS NULL OR stock = '';
-- It is stock that with values zero, it is possible the stocks are zero, so no need to remove them.

-- 3. Data cleaning operations to ensure data integrity and consistency.
-- Removing null from sales in product_id column
DELETE FROM sales WHERE product_id = '';
-- Replacing null with average values of sales table in quantity column
SELECT ROUND(AVG(cast(quantity AS FLOAT))) avg_quantity FROM sales WHERE quantity != ''; /*Average is 4 */
UPDATE sales SET quantity = 4 WHERE quantity = '';
-- Verifying the changes
SELECT * FROM sales WHERE quantity = '';
-- Empty table returned, hence no missing values
-- Since the quantity is character changing it to ineteger
ALTER TABLE sales
MODIFY COLUMN quantity INT;
select count(*) from sales; /*5108 rows left after deleting blank product ids'

/***************************** Data Analysis*****************************/
-- 1. Number of customers by gender: Here I am creating VIEW to use it in visualization in Power BI.
CREATE VIEW cust_num_gen AS SELECT gender, COUNT(*) numbers_of_cust FROM customers GROUP BY gender;
-- 2. Age range
SELECT MIN(age) min_age, MAX(age) max_age  FROM customers ;
-- 3. Order date range
SELECT MAX(date), MIN(date) from sales; /* 2019–01–03 to 2022–12–30*/
-- 4. Highest transaction year
CREATE VIEW txn_year AS SELECT YEAR(Date) year, COUNT(*) Num_of_txns 
FROM sales GROUP BY year ORDER BY Num_of_txns DESC ;
-- 5. Highest transaction month
CREATE VIEW txn_month AS SELECT MONTHNAME(Date) month, COUNT(*) Num_of_txns 
FROM sales GROUP BY month ORDER BY Num_of_txns DESC ;
-- 6. Highest transaction day
CREATE VIEW txn_Day AS SELECT DAYNAME(Date) day_of_week, COUNT(*) Num_of_txns 
FROM sales GROUP BY day_of_week ORDER BY Num_of_txns DESC ;
-- 7. Year with highest sales
CREATE VIEW sale_year AS SELECT YEAR(Date) year, SUM(amount) tot_sale 
FROM sales GROUP BY year ORDER BY tot_sale DESC ; /*2022 highest sales*/
-- 8. Month with highest sales
CREATE VIEW sale_mon AS SELECT MONTHNAME(Date) month, SUM(amount) tot_sale 
FROM sales GROUP BY month ORDER BY tot_sale DESC ;
-- 9.Day of week with highest sales
/*CREATE VIEW sale_day AS */SELECT Date,DAYNAME(Date) day_of_week, SUM(amount) tot_sale 
FROM sales GROUP BY Date,day_of_week ORDER BY tot_sale DESC ;
-- 10 sales by gender
CREATE VIEW sale_gen AS SELECT gender, SUM(s.amount) tot_sale 
FROM sales s JOIN customers c USING(customer_id) /* Here column names are same so I can use USING instead of ON s.customer_id=c.customer_id*/
GROUP BY gender ORDER BY tot_sale DESC ;

-- 11 transactions by gender
CREATE VIEW txn_gen AS SELECT  gender, COUNT(transaction_id) Num_of_txns 
FROM sales s JOIN customers c USING(customer_id)
GROUP BY gender ORDER BY Num_of_txns DESC ;
-- 12 transactions by age
CREATE VIEW txn_age  AS
SELECT  age, COUNT(transaction_id) Num_of_txns 
FROM sales s JOIN customers c USING(customer_id)
 GROUP BY age ORDER BY Num_of_txns DESC ;
-- 13 sales by age
CREATE VIEW sale_age AS SELECT  age,  SUM(s.amount) tot_sale
FROM sales s JOIN customers c USING(customer_id)
GROUP BY age ORDER BY tot_sale DESC ;
-- 14 Percentage of products with zero stocks
SELECT CONCAT((SELECT COUNT(*) FROM inventory WHERE stock=0)/COUNT(*)*100, ' %') zero_stock_percent 
FROM inventory ;
-- 15 Product category with stock zero
CREATE VIEW stock_zero AS SELECT category, COUNT(*) num_of_products
FROM inventory i 
INNER JOIN products p USING(product_id) 
WHERE stock=0 GROUP BY category;

-- 16.total revenue generated by the company for each product category
CREATE VIEW product_revenue AS
SELECT p.category, ROUND(SUM(p.price * s.quantity)) AS Revenue  FROM SALES s 
JOIN products p 
USING(product_id)
GROUP BY p.category;
/*I joined the tables based on common coloumn that is product id, the type of join used is inner join because only common records are needed*/

-- 17.top 5 customers who have made the highest total purchases, considering the customer's age and gender.
CREATE VIEW top5 AS WITH cte AS (
SELECT *, SUM(amount) OVER(PARTITION BY c.customer_id ) as purchase from customers c
JOIN sales s USING(customer_id))
SELECT  DISTINCT customer_id, cust_name, age, gender,purchase  FROM cte   ORDER BY purchase DESC LIMIT 5;

/* I used common table expression (CTE) with help of this we can select multiple columns with aggregated column 
which is not possible to do using simple select statement, I also used WINDOW FUNCTION to SUM with PARTITION to get total amount by customers
 and inner joins to fetch common records from other table*/

-- 18. Identify the most profitable product category by calculating the average revenue per unit sold.
CREATE VIEW profitable_category AS WITH cte AS(
SELECT *, SUM(p.price*s.quantity) OVER(PARTITION BY p.category) AS revenue  FROM SALES s 
JOIN products p 
USING(product_id)
)
SELECT category, ROUND(AVG(revenue/quantity)) as rev_per_unit_sold from cte
GROUP BY category ORDER BY rev_per_unit_sold DESC;

/************************** Analysis and Reporting**************************/ 
-- 19.the average age of customers for each product category. 
CREATE VIEW avg_age_by_category AS WITH cte AS(
SELECT category, AVG(c.age) OVER(PARTITION BY p.category) AS avg_age_by_product FROM customers c
JOIN sales s USING(customer_id)
JOIN products p USING(product_id))
SELECT  DISTINCT category, ROUND(avg_age_by_product) AS avg_age_by_product_category FROM cte;

-- 20. the top  product category that have the highest average transaction amount. 
CREATE VIEW top_txn_amt_category AS WITH cte as(
SELECT *, AVG(s.amount) OVER(PARTITION BY p.category ) AS avg_txn FROM sales S
JOIN products P USING(product_id))
SELECT DISTINCT category, ROUND(avg_txn) AS avg_txn_amount 
FROM cte ORDER BY avg_txn_amount DESC ; 

-- 21. I'll find out which gender category is buying high price product
WITH cte AS(
SELECT *,  AVG(price) OVER(PARTITION BY c.gender) AS price_val FROM products p 
JOIN sales s USING(product_id)
JOIN customers c USING(customer_id))
SELECT DISTINCT  gender,  price_val FROM cte ORDER BY price_val DESC; 
-- Female buying more expensive product than male

-- 22.Average price of products by age group
WITH cte AS(
SELECT customer_id, CASE 
WHEN age >= 18 AND age <=30 THEN 'Youth'
WHEN age >30 AND age <= 45 THEN 'Middle Age Adults'
ELSE 'Old Age Adults'
END AS age_group FROM customers),
cte2 as( 
SELECT *,  avg(amount) OVER(PARTITION BY cte.age_group ORDER BY cte.age_group DESC) AS avg_amount FROM products p 
JOIN sales s USING(product_id)
JOIN customers c USING(customer_id)
JOIN cte using(customer_id))
SELECT DISTINCT age_group,  round(avg_amount) FROM CTE2; 

-- 23.Popular product category by gender
CREATE VIEW pop_cat_gen AS SELECT c.gender, p.category, COUNT(*) popular_category
FROM products p JOIN sales s USING(product_id)
JOIN customers c USING(customer_id)
GROUP BY c.gender, p.category ORDER BY popular_category DESC;

-- 24. By age range: Here I created age brackets to better understand the popularity among different age groups.
CREATE VIEW pop_cat_age AS SELECT CASE 
WHEN age >= 18 AND age <=30 THEN 'Youth'
WHEN age >30 AND age <= 45 THEN 'Middle Age Adults'
ELSE 'Old Age Adults'
END AS age_group,
p.category, COUNT(*) popular_category
FROM products p JOIN sales s USING(product_id)
JOIN customers c USING(customer_id)
GROUP BY age_group, p.category ORDER BY popular_category DESC;
-- After creating that I imported the views to Power BI for visualisation

