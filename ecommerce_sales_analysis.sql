create database ecommerce_analysis;
use ecommerce_analysis;
select database();

-- 1.Customers table
create table customers(customer_id varchar(50) primary key,customer_unique_id varchar(50),customer_zip_code_prefix int,customer_city varchar(100),customer_state char(2));

-- 2.Orders table
create table orders(order_id varchar(50) primary key,customer_id varchar(50),order_status varchar(30),order_purchase_timestamp datetime,order_approved_at datetime,order_delivered_carrier_date datetime,order_delivered_customer_date datetime,order_estimated_delivery_date datetime);

-- 3.Order items table
create table order_items(order_id varchar(50),order_item_id int,product_id varchar(50),seller_id varchar(50),shipping_limit_date datetime,price decimal(10,2),freight_value decimal(10,2),primary key(order_id,order_item_id));

-- 4.Prodcts table
create table products(product_id varchar(50) primary key,product_category_name varchar(100),product_name_lenght int,product_description_lenght int,product_photos_qty int,product_weight_g int,product_length_cm int,product_height_cm int,product_width_cm int);
show tables;

use ecommerce_analysis;
select count(*) as total_customers from customers;
select * from customers limit 5;

select count(*) as total_orders from orders;

select count(*) as total_order_items from order_items;

select count(*) as total_products from products;

-- data validation and understanding
describe customers;
describe orders;
describe order_items;
describe products;

-- check missing customer information
select sum(customer_id is null) as missing_customer_id,
	   sum(customer_city is null) as missing_city,
       sum(customer_state is null) as missing_state
from customers;

-- check missing order information
select sum(order_id is null) as missing_order_id,
       sum(customer_id is null) as missing_customer_id,
       sum(order_status is null) as missing_order_status
from orders;

-- check missing order item information
select sum(order_id is null) as missing_order_id,
       sum(product_id is null) as missing_product_id,
       sum(price is null) as missing_price
from order_items;

-- check missing product information
select sum(product_id is null) as missing_product_id,
       sum(product_category_name is null) as missing_category_name
from products;

-- check duplicate customer IDs
select customer_id,count(*) as occurrences from customers group by customer_id having count(*)>1;

-- check duplicate order IDs
select order_id,count(*) as occurrences from orders group by order_id having count(*)>1;

-- check duplicate product IDs
select product_id,count(*) as occurrences from products group by product_id having count(*)>1;

-- check relationships between tables
-- orders that have no matching customer
select count(*) as unmatched_orders 
from orders o 
left join customers c
    on o.customer_id=c.customer_id
where c.customer_id is null;

-- order items that have no matching order
select count(*) as unmatched_order_itms
from order_items oi
left join orders o
    on oi.order_id=o.order_id
where o.order_id is null;

-- order_items that have no matching product
select count(*) as unmatched_products
from order_items oi 
left join products p
    on oi.product_id=p.product_id
where p.product_id is null;

-- understand order status
select order_status,count(*) as total_orders
from orders
group by order_status
order by total_orders desc;

-- calculate sales performance
select count(distinct o.order_id) as total_orders,
       count(*) as total_order_items,
       round(sum(oi.price),2) as product_revenue,
       round(sum(oi.freight_value),2) as total_freight,
       round(avg(oi.price),2) as average_item_price,
       round(avg(oi.freight_value),2) as average_freight_per_item
from orders o
join order_items oi 
on o.order_id=oi.order_id
where o.order_status="delivered";	

-- analyze monthly sales
select date_format(o.order_purchase_timestamp,'%y-%m')
       as order_month,
       count(distinct o.order_id) as total_orders,
       round(sum(oi.price),2) as product_revenue
from orders o 
join order_items oi
     on o.order_id=oi.order_id
where o.order_status="delivered"
and o.order_purchase_timestamp is not null
group by date_format(o.order_purchase_timestamp,'%y-%m')
order by order_month;
       
-- top selling product categories       
select coalesce(p.product_category_name,"unkown")
        as product_category,
        count(*) as items_sold,
        count(distinct o.order_id) as orders_containing_category,
        round(sum(oi.price),2) as product_revenue
        from order_items oi
        join orders o
         on oi.order_id=o.order_id
		join products p
          on oi.product_id=p.product_id
		where o.order_status="delivered"
        group by coalesce(p.product_category_name,"unkown")
        order by product_revenue desc
        limit 10;

-- best performinng customer states
select c.customer_state,
       count(distinct o.order_id) as total_orders,
       round(sum(oi.price),2) as product_revenue
from customers c join orders o 
on c.customer_id=o.customer_id
join order_items oi
on o.order_id =oi.order_id
where o.order_status="delivered"
group by c.customer_state
order by product_revenue desc
limit 10;

-- identify repeat customers 
with customer_orders as(
 select c.customer_unique_id,
        count(distinct o.order_id) as total_orders,
        sum(oi.price) as product_revenue
from customers c
join orders o 
  on c.customer_id=o.customer_id
join order_items oi
  on o.order_id=oi.order_id
where o.order_status="delivered"
group by c.customer_unique_id)
select 
   case 
      when total_orders=1 then "one delivered order"
      else "repeat customers"
   end as customer_segment,
   count(*) as total_customers,
   round(sum(product_revenue),2) as product_revenue,
   round(avg(product_revenue),2) as average_customer_revenue
from customer_orders
group by customer_segment
order by total_customers desc;

-- analyze delivery performance
select count(*) as delivered_orders_with_dates,
       round(avg(datediff(order_delivered_customer_date,
                          order_purchase_timestamp)),2)
                          as avg_delivery_days,
	   round(avg(datediff(order_estimated_delivery_date,
                          order_delivered_customer_date)),2)
                          as avg_days_early
from orders
where order_status="delivered"
and order_purchase_timestamp is not null
and order_delivered_customer_date is not null
and order_estimated_delivery_date is not null;
       
-- average order value
with order_revenue as(
 select 
       o.order_id,
       sum(oi.price) as order_product_revenue
from orders o 
join order_items oi
 on o.order_id =oi.order_id
where o.order_status="delivered"
group by o.order_id)
select 
    count(*) as delivered_orders,
    round(avg(order_product_revenue),2) as average_order_value,
    round(sum(order_product_revenue),2) as total_product_revenue
    from  order_revenue;

-- rank_categoories
WITH category_sales AS (
    SELECT
        COALESCE(p.product_category_name, 'Unknown') AS product_category,
        SUM(oi.price) AS product_revenue
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY COALESCE(p.product_category_name, 'Unknown')
),
ranked_categories AS (
    SELECT
        product_category,
        product_revenue,
        DENSE_RANK() OVER (
            ORDER BY product_revenue DESC
        ) AS revenue_rank
    FROM category_sales
)
SELECT
    revenue_rank,
    product_category,
    ROUND(product_revenue, 2) AS product_revenue
FROM ranked_categories
WHERE revenue_rank <= 10
ORDER BY revenue_rank;
     






