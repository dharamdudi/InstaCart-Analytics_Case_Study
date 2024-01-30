--Creating a Schema
CREATE SCHEMA InstaCart;

--Setting a default search path to the created schema
SET search_path = 'InstaCart';

--Creating the 5 tables

CREATE TABLE ic_order_products_curr(
   order_id         INTEGER  NOT NULL
  ,product_id       INTEGER  NOT NULL
  ,add_to_cart_order INTEGER  NOT NULL
  ,reordered           INTEGER  NOT NULL
);

CREATE TABLE ic_order_products_prior(
   order_id         INTEGER  NOT NULL
  ,product_id       INTEGER  NOT NULL
  ,add_to_cart_order INTEGER  NOT NULL
  ,reordered           INTEGER  NOT NULL
);

CREATE TABLE ic_products(
   product_id    INTEGER  NOT NULL PRIMARY KEY 
  ,product_name  VARCHAR(500) NOT NULL
  ,aisle_id      INTEGER  NOT NULL
  ,department_id INTEGER  NOT NULL
);

CREATE TABLE ic_aisles(
   aisle_id INTEGER  NOT NULL PRIMARY KEY 
  ,aisle      VARCHAR(29) NOT NULL
);

CREATE TABLE ic_departments(
   department_id INTEGER  NOT NULL PRIMARY KEY 
  ,department      VARCHAR(50) NOT NULL
);


--Creating 2 views for both current and prior tables to facilitate further analysis process.

CREATE VIEW ic_agg_curr AS
SELECT product_id,
	COUNT(*) AS total_units_sold,
	ROUND(AVG(add_to_cart_order)) AS avg_cart_order,
	SUM(reordered) AS total_reorders
FROM ic_order_products_curr
GROUP BY product_id;

CREATE VIEW ic_agg_prior AS
SELECT product_id,
	COUNT(*) AS total_units_sold,
	ROUND(AVG(add_to_cart_order)) AS avg_cart_order,
	SUM(reordered) AS total_reorders
FROM ic_order_products_prior
GROUP BY product_id;

--Distribution of the Products Sold by Departments
SELECT id.department AS "Department",
	COUNT(DISTINCT aisle_id) AS "Total Aisles",
  	COUNT(DISTINCT product_id) AS "Total Products",
  	SUM(iac.total_units_sold) AS "Total Sold in Q3",
  	SUM(iap.total_units_sold) AS "Total Sold in Q2"
FROM ic_products ip
JOIN ic_departments id USING(department_id)
LEFT JOIN ic_agg_curr iac USING(product_id)
LEFT JOIN ic_agg_prior iap USING(product_id)
GROUP BY id.department
ORDER BY "Total Sold in Q3" DESC,
	"Total Sold in Q2" DESC;


--Total distinct products sold
SELECT COUNT(distinct product_id) 
FROM ic_order_products_prior;

--Avg no of items in a particular order
WITH total_items AS (
	SELECT order_id, COUNT(product_id) AS total_items
	FROM ic_order_products_curr
	GROUP BY 1)

SELECT ROUND(AVG(total_items)) AS avg_items_per_order
FROM total_items;

--Highest & lowest no of items in a particular order
WITH total_items AS (
	SELECT order_id, COUNT(product_id) AS total_items
	FROM ic_order_products_curr
	GROUP BY 1)

SELECT MAX(total_items), MIN(total_items)
FROM total_items;

--Order Cart Segmentation Analysis
WITH curr_items AS (
	SELECT order_id, COUNT(product_id) AS total_items
	FROM ic_order_products_prior
	GROUP BY 1),

prior_items AS (
	SELECT order_id, COUNT(product_id) AS total_items
	FROM ic_order_products_curr
	GROUP BY 1)

SELECT
	'Q3' AS "Quarter",
	COUNT(CASE WHEN total_items BETWEEN 1 AND 5 THEN TRUE ELSE NULL END) AS "1-5 Items",
	COUNT(CASE WHEN total_items BETWEEN 6 AND 10 THEN TRUE ELSE NULL END) AS "6-10 Items",
	COUNT(CASE WHEN total_items BETWEEN 11 AND 20 THEN TRUE ELSE NULL END) AS "11-20 Items",
	COUNT(CASE WHEN total_items BETWEEN 21 AND 30 THEN TRUE ELSE NULL END) AS "21-30 Items",
	COUNT(CASE WHEN total_items BETWEEN 31 AND 45 THEN TRUE ELSE NULL END) AS "30-45 Items",
	COUNT(CASE WHEN total_items > 45 THEN TRUE ELSE NULL END) AS "More than 45 Items"	
FROM curr_items

UNION

SELECT
	'Q2' AS "Quarter",
	COUNT(CASE WHEN total_items BETWEEN 1 AND 5 THEN TRUE ELSE NULL END) AS "1-5 Items",
	COUNT(CASE WHEN total_items BETWEEN 6 AND 10 THEN TRUE ELSE NULL END) AS "6-10 Items",
	COUNT(CASE WHEN total_items BETWEEN 11 AND 20 THEN TRUE ELSE NULL END) AS "11-20 Items",
	COUNT(CASE WHEN total_items BETWEEN 21 AND 30 THEN TRUE ELSE NULL END) AS "21-30 Items",
	COUNT(CASE WHEN total_items BETWEEN 31 AND 45 THEN TRUE ELSE NULL END) AS "30-45 Items",
	COUNT(CASE WHEN total_items > 45 THEN TRUE ELSE NULL END) AS "More than 45 Items"	
FROM prior_items;

--Top 10 Products Sold
WITH units_sold AS (
	SELECT *,
		DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS rank
	FROM ic_agg_curr)

SELECT ip.product_name AS "Product",
	us.total_units_sold "Total Units Sold"
FROM units_sold us
LEFT JOIN ic_products ip USING(product_id)
WHERE us.rank<=10
ORDER BY us.total_units_sold DESC;

--Top 10 Products and their rank change compared to previous quarter Q2
WITH curr_units_sold AS(
	SELECT *,
		DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS rank
	FROM ic_agg_curr),

prior_units_sold AS (
	SELECT *,
		DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS rank
	FROM ic_agg_prior)

SELECT ip.product_name AS "Product", 
	id.department AS "Department",
	cus.total_units_sold AS "Total Orders (Q3)",
	cus.rank AS "Rank (Q3)",
	pus.total_units_sold AS "Total Orders (Q2)",
	pus.rank AS "Rank (Q2)"
FROM curr_units_sold cus
LEFT JOIN prior_units_sold pus USING(product_id)
LEFT JOIN ic_products ip USING(product_id)
LEFT JOIN ic_departments id USING(department_id)
WHERE cus.rank<=10
ORDER BY cus.rank;

-- In what order the top 10 products are being added to the cart?
WITH curr_units_sold AS (
	SELECT product_id, total_units_sold, avg_cart_order,
		DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS rank
	FROM ic_agg_curr)

SELECT ip.product_name AS "Product",
	ia.aisle AS "Aisle",
	cus.total_units_sold AS "Total Units Sold",
	cus.avg_cart_order AS "Avg Cart Order"
FROM curr_units_sold cus
LEFT JOIN ic_products ip USING(product_id)
LEFT JOIN ic_aisles ia USING(aisle_id)
LEFT JOIN ic_departments id USING(department_id)
WHERE cus.rank<=10
ORDER BY cus.rank;

--- Top sellers join carts late (4th+ position). So, what fills carts early?
SELECT COUNT(ip.product_name) AS "Product",
	SUM(c.total_units_sold) AS "Total Sold"
FROM ic_agg_curr c
LEFT JOIN ic_products ip USING(product_id)
WHERE c.avg_cart_order=1;

	--In What Aisles? Distribution by Aisles
SELECT ia.aisle AS "Asile",
	COUNT(product_id) AS "Total Products"
FROM ic_agg_curr c
LEFT JOIN ic_products ip USING(product_id)
LEFT JOIN ic_departments id USING(department_id)
LEFT JOIN ic_aisles ia USING(aisle_id)
WHERE c.avg_cart_order=1
GROUP BY ia.aisle
ORDER BY COUNT(product_id) DESC;

-- Cart order Behaviour
SELECT avg_cart_order AS "Avg Cart Order",
	COUNT(product_id) AS "Total Products",
	SUM(total_units_sold) AS "Total Units Sold", 
	SUM(total_reorders) AS "Total Reorders"
FROM ic_agg_curr
GROUP BY avg_cart_order
ORDER BY avg_cart_order;

-- Top 10 Aisles by Total Units Sold
SELECT ia.aisle, count(product_id)
FROM ic_order_products_curr c
LEFT JOIN ic_products ip USING(product_id)
LEFT JOIN ic_aisles ia USING(aisle_id)
GROUP BY 1
ORDER BY 2 DESC;

-- Change in behaviour of products purchased currently vs prior
WITH pct_change_reorders AS (
	SELECT ip.product_name,
		ia.aisle,
		iap.total_reorders as prior_reorders,
		iac.total_reorders as curr_reorders,
		ROUND((iac.total_reorders - iap.total_reorders)*100.0/iap.total_reorders) AS change_pct
	FROM ic_agg_curr iac
	LEFT JOIN ic_agg_prior iap USING(product_id)
	LEFT JOIN ic_products ip USING(product_id)
	LEFT JOIN ic_aisles ia USING(aisle_id)
	WHERE (iap.total_reorders>=5 AND iac.total_reorders>=5)
	ORDER BY 4 DESC)

SELECT product_name AS "Product",
	aisle AS "Aisle",
	prior_reorders AS "Total Reorders (Q2)",
	curr_reorders AS "Total Reorders (Q3)",
	change_pct || '%' AS "% Change"
FROM pct_change_reorders
WHERE ABS(change_pct)>=50
ORDER BY change_pct DESC;