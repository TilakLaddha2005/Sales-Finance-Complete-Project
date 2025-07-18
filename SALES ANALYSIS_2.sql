-----------------------------------------------------------------------------------
-- 8. Cohort Analysis – Revenue by Customer Signup Year

SELECT 
DATE_PART('YEAR' , cus.customer_since) AS year,
SUM(CASE WHEN o.order_status = 'Completed' THEN 1 ELSE 0 END) AS total_orders,
COUNT(DISTINCT cus.customer_id) AS total_customers,
SUM(CASE WHEN o.order_status = 'Completed' then oi.total_price ELSE 0 END) AS total_revenue,
(SUM(CASE WHEN o.order_status = 'Completed' then oi.total_price ELSE 0 END) / COUNT(DISTINCT cus.customer_id) ) AS avg_revenue_per_customer
FROM customers cus
JOIN orders o ON o.customer_id = cus.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY DATE_PART('YEAR' , cus.customer_since)
ORDER BY DATE_PART('YEAR' , cus.customer_since);

-----------------------------------------------------------------------------------
-- 9. Purchase Frequency by Customer Segment (New , Existing)

WITH customer_segments AS(
	SELECT *,
	CASE WHEN customer_since >= CURRENT_DATE - INTERVAL '1' YEAR THEN 'NEW' 
	ELSE 'Existing' END AS segments
	FROM customers ),

total_customers_count as(
	select 
	cs.segments,
	count(cs.customer_id) as total_customers
	from customer_segments cs
	group by cs.segments)

SELECT 
cs.segments,
(tcc.total_customers) AS total_customers,
COUNT(o.order_id) AS total_orders,
SUM(oi.total_price) AS total_revenue,
COUNT(DISTINCT o.order_id) / (tcc.total_customers) AS avg_order_per_customer,
SUM(oi.total_price) / (tcc.total_customers) AS aov_per_segments
FROM customer_segments cs
JOIN orders o ON cs.customer_id = o.customer_id 
JOIN order_items oi ON oi.order_id = o.order_id
JOIN total_customers_count tcc ON tcc.segments = cs.segments
WHERE o.order_status = 'Completed'
GROUP BY cs.segments ,tcc.total_customers;

-----------------------------------------------------------------------------------
-- 10. Lead/Lag Analysis – Time Between Consecutive Orders

with customer_data as(
	select 
	o.customer_id,
	cus.customer_name,
	o.order_id ,
	lag(o.order_date) over(partition by o.customer_id order by o.order_date) as prev_order_date,
	o.order_date as order_date,
	lead(o.order_date) over(partition by o.customer_id order by o.order_date) as next_order_date
	from orders o 
	join customers cus on cus.customer_id = o.customer_id
	group by o.customer_id , cus.customer_name , o.order_id , o.order_date)

select cd.*,
(cd.order_date - cd.prev_order_date) as days_between_prev,
(cd.next_order_date - cd.order_date ) as days_to_next
from customer_data cd;

-----------------------------------------------------------------------------------
-- 11. First-Time vs Returning Customer Revenue

with first_order_data as(
	select 
	o.customer_id ,
	cus.customer_name,
	min(o.order_date) as first_order_date
	from orders o
	join customers cus on cus.customer_id = o.customer_id
	where o.order_status = 'Completed'
	group by o.customer_id , cus.customer_name),
	
segment_data as(
	select *,
	case when o.order_date = fod.first_order_date then 'New' else 'Returing' end as segment
	from first_order_data fod
	join orders o on fod.customer_id = o.customer_id
	where o.order_status = 'Completed'),

revenue_data as(
	select 
	sd.segment,
	sd.order_id,
	SUM(oi.total_price) as revenue
	from segment_data sd
	join order_items oi on sd.order_id = oi.order_id
	group by sd.segment , sd.order_id)
	
select 
rd.segment,
count(rd.order_id) as total_orders,
sum(rd.revenue) as total_revenue,
sum(rd.revenue) / count(rd.order_id) as avg_order_value 
from revenue_data rd
group by rd.segment;

----------------------------------------------------------------------------------
-- 12. LTV by Acquisition state

with customer_data as(
	select 
	cus.customer_id,
	cus.customer_name,
	cus.customer_state as state,
	o.order_id,
	sum(oi.total_price) as revenue
	from customers cus
	join orders o on cus.customer_id = o.customer_id
	join order_items oi on oi.order_id = o.order_id
	where o.order_status = 'Completed'
	group by cus.customer_id , cus.customer_name , cus.customer_state , o.order_id)

select 
cd.state,
count(distinct cd.customer_id) as total_customers,
count(distinct cd.order_id) as total_orders,
sum(cd.revenue) as total_revenue,
(sum(cd.revenue) / count(cd.customer_id)) as avg_ltv_per_customer,
(sum(cd.revenue) / count(cd.order_id)) as aov,
rank() over(order by sum(cd.revenue)) as rank_
from customer_data cd
group by cd.state
order by rank_;

-----------------------------------------------------------------------------------
-- 13. Year-Over-Year Revenue Growth

select 
date_part('year' , o.order_date) as year,
sum(oi.total_price) as total_revenue,
lag(sum(oi.total_price)) over(order by date_part('year' , o.order_date)) as prev_year_revenue,
((sum(oi.total_price) - lag(sum(oi.total_price)) over(order by date_part('year' , o.order_date))) * 100 /
lag(sum(oi.total_price)) over(order by date_part('year' , o.order_date))) as yoy_growth
from orders o
join order_items oi on oi.order_id = o.order_id
where o.order_status = 'Completed'
group by date_part('year' , o.order_date)

-----------------------------------------------------------------------------------
-- 14. Repeat Purchase Rate

with customer_data as(
	select 
	o.customer_id,
	count(o.order_id) as total_orders
	from orders o
	where o.order_status = 'Completed'
	group by o.customer_id )


select 
extract( 'month' from o.order_date) as month_number,
to_char(o.order_date , 'Month') as month_,
count(*) filter(where cd.total_orders > 1 ) as repeated_customers,
count(*) filter(where cd.total_orders = 1) as one_time_customers,
count(*) as total_customers,
count(*) filter(where cd.total_orders > 1 ) * 100 / count(*) as repeat_purchase_rate
from customer_data cd
join orders o on cd.customer_id = o.customer_id
group by month_number , month_ 
order by month_number

-----------------------------------------------------------------------------------
-- 15. Sales Concentration: % Revenue from Top 20% Customers

with customer_rev_data as(
	select 
	o.customer_id,
	sum(oi.total_price) as revenue,
	rank() over(order by sum(oi.total_price) desc) as rank
	from orders o 
	join order_items oi on oi.order_id = o.order_id
	group by o.customer_id
	order by sum(oi.total_price) DESC),

total_customers AS (
  SELECT COUNT(*) AS total FROM customer_rev_data),

top_20_percent_customers AS (
  SELECT 
    crd.*
  FROM customer_rev_data crd
  JOIN total_customers tc ON TRUE
  WHERE crd.rank <= ROUND(tc.total * 0.20)),

total_revenue AS (
  SELECT SUM(revenue) AS total_revenue FROM customer_rev_data),

top_20_revenue AS (
  SELECT SUM(revenue) AS top_20_revenue FROM top_20_percent_customers)

SELECT 
  tr.total_revenue,
  t20.top_20_revenue,
  (t20.top_20_revenue * 100.0 / tr.total_revenue) AS top_20_percent_contribution
FROM total_revenue tr, top_20_revenue t20;

-----------------------------------------------------------------------------------
