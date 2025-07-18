-- Sales and Finance analysics of data 
---------------------------------------------------------------
-- 1. Average Order Value (AOV) by Month

SELECT 
DATE_PART('YEAR',o.order_date) AS years,
EXTRACT(MONTH FROM o.order_date) as month_number,
TO_CHAR(o.order_date , 'Month') AS months,
SUM(oi.total_price) / COUNT(DISTINCT o.order_id) AS AOV,
RANK() OVER(PARTITION BY (DATE_PART('YEAR',o.order_date)) 
ORDER BY (SUM(oi.total_price) / COUNT(DISTINCT o.order_id)) DESC) AS rank_by_aoc
FROM orders o 
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY years,month_number,months
ORDER BY years , month_number ASC;

---------------------------------------------------------------
-- 1.1. Average Order Value (AOV) 

SELECT 
SUM(oi.total_price) AS total_revenue,
COUNT(DISTINCT o.order_id) AS total_orders,
SUM(oi.total_price) / NULLIF(COUNT(o.order_id),0) AS AOV
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed';

---------------------------------------------------------------
-- 2. RFM Segmentation (Recency, Frequency, Monetary)

CREATE VIEW customer_segmentation_rfm AS(
WITH customer_data AS(
SELECT 
c.customer_id,
c.customer_name AS name,
MAX(o.order_date) AS last_order_date,
COUNT(o.order_id) AS frequency,
SUM(oi.total_price) AS monetary
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY c.customer_id,c.customer_name),

scored_data AS(
SELECT cd.*,
(SELECT MAX(order_date) FROM orders) - last_order_date AS recency,

CASE WHEN cd.frequency > 12 THEN 5
     WHEN cd.frequency > 8 THEN 4
     WHEN cd.frequency > 5 THEN 3
     WHEN cd.frequency > 3 THEN 2
     WHEN cd.frequency > 1 THEN 1 ELSE 0 END AS f_score,
	 
CASE WHEN cd.monetary  > 5000 THEN 5
     WHEN cd.monetary  > 3000 THEN 4
     WHEN cd.monetary  > 2000 THEN 3
     WHEN cd.monetary  > 1000 THEN 2
     WHEN cd.monetary  > 500  THEN 1 ELSE 0 END AS m_score,
	 
CASE WHEN (SELECT MAX(order_date) FROM orders) - last_order_date  < 300 THEN 5
     WHEN (SELECT MAX(order_date) FROM orders) - last_order_date  < 450 THEN 4
     WHEN (SELECT MAX(order_date) FROM orders) - last_order_date  < 600 THEN 3
     WHEN (SELECT MAX(order_date) FROM orders) - last_order_date  < 800 THEN 2
     WHEN (SELECT MAX(order_date) FROM orders) - last_order_date  < 900 THEN 1 ELSE 0 END AS r_score
FROM customer_data cd),

segmented_data AS(
SELECT sd.*,
CASE WHEN f_score >= 4 AND m_score >= 4 AND r_score >= 4 THEN 'GOLD'
     WHEN f_score >= 3 AND m_score >= 3 AND r_score >= 3 THEN 'SILVER'
	 WHEN f_score >= 2 AND m_score >= 2 AND r_score >= 2 THEN 'BRONZE' ELSE 'COMMON' END AS customer_segment,

CASE WHEN f_score >= 3 THEN 'REGULAR'
     WHEN f_score >= 1 THEN 'POTENTIAL' ELSE 'POSSIBLE' END AS frequency_segment,

CASE WHEN m_score >= 4 THEN 'HIGH_VALUE'
     WHEN m_score >= 3 THEN 'MID_VALUE' ELSE 'LOW_VALUE' END AS monetary_segment,

CASE WHEN r_score >= 4 THEN 'SAFE'
     WHEN r_score >= 2 THEN 'AT RISK' ELSE 'CHURNED' END AS recency_segment
FROM scored_data sd )

SELECT *,
CONCAT(r_score::TEXT, f_score::TEXT, m_score::TEXT) AS rfm_string
FROM segmented_data )

---------------------------------------------------------------
-- 3. Customer Lifetime Value (CLV) with Average Order Value × Frequency

SELECT 
cus.customer_id,
cus.customer_name AS name_,
SUM(oi.total_price) AS clv,
COUNT(o.order_id) AS frequency,
(SUM(oi.total_price) / COUNT(DISTINCT o.order_id)) AS aov
FROM customers cus
JOIN orders o ON o.customer_id = cus.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY cus.customer_id, cus.customer_name 
ORDER BY SUM(oi.total_price) DESC

---------------------------------------------------------------
-- 4. Churn Prediction – Inactive Customers (no orders in last 180 days)

WITH churned_customer AS(
SELECT 
cus.customer_id,
cus.customer_name AS name_,
MAX(o.order_date) AS last_order_date
FROM customers cus
JOIN orders o ON o.customer_id = cus.customer_id
WHERE o.order_status = 'Completed'
GROUP BY cus.customer_id, cus.customer_name 
HAVING MAX(o.order_date) < (SELECT MAX(order_date) FROM orders) - INTERVAL '180 DAYS')

SELECT 
COUNT(cc.customer_id) AS total_churned_customers,
(SELECT COUNT(customer_id) FROM customers) AS total_customers,
COUNT(cc.customer_id) * 100 / (SELECT COUNT(customer_id) FROM customers) AS churned_rate_pct
FROM churned_customer cc;

---------------------------------------------------------------
-- 5. Time Between First and Last Purchase per Customer

SELECT 
cus.customer_id,
cus.customer_name AS name_,
MIN(o.order_date) AS first_order_date,
MAX(o.order_date) AS last_order_date,
(MAX(o.order_date) - MIN(o.order_date)) AS customer_lifecycle_days
FROM customers cus
JOIN orders o ON o.customer_id = cus.customer_id
WHERE o.order_status = 'Completed'
GROUP BY cus.customer_id, cus.customer_name
ORDER BY (MAX(o.order_date) - MIN(o.order_date)) DESC;

---------------------------------------------------------------
-- 6. Basket Size (Average Products Per Order)

SELECT AVG(product_count) AS Average_Products_Per_Order
FROM(
SELECT 
order_id,
COUNT(*) AS product_count
FROM order_items 
GROUP BY order_id) orders_product_count;

---------------------------------------------------------------
-- 7.Category Pairing by total Orders together 

SELECT 
p1.category AS cat_1,
p2.category AS cat_2,
COUNT(DISTINCT o.order_id) AS co_occurence_count
FROM order_items oi1 JOIN order_items oi2 on oi2.order_id = oi1.order_id
AND oi2.product_id < oi1.product_id
JOIN products p1 ON p1.product_id = oi1.product_id
JOIN products p2 ON p2.product_id = oi2.product_id
JOIN orders o ON o.order_id = oi1.order_id
WHERE oi1.order_id = oi2.order_id AND o.order_status = 'Completed'
GROUP BY p1.category, p2.category
ORDER BY co_occurence_count desc;

---------------------------------------------------------------
