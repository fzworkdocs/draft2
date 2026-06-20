SELECT * FROM customers;
SELECT * FROM order_items;
SELECT * FROM geolocation;
SELECT * FROM orders;
SELECT * FROM order_payments;
SELECT * FROM order_reviews;
SELECT * FROM product_category_name_translation;
SELECT * FROM products;
SELECT * FROM sellers;

--CHECK FOR NULLS & DUPLICATES
--CUSTOMER TABLE
SELECT 
    COUNT(*) total_rows,
    COUNT(*)-COUNT(customer_id) AS id_nullcount,
    COUNT(*)-COUNT(customer_unique_id) AS uniqueid_nullcount,
    COUNT(*)-COUNT(customer_zip_code_prefix) AS zipcode_nullcount,
    COUNT(*)-COUNT(customer_city) AS city_nullcount,
    COUNT(*)-COUNT(customer_state) AS state_nullcount,
    COUNT(customer_id) - COUNT(DISTINCT customer_id) AS id_duplicates
FROM customers

--ORDER_ITEMS TABLE
SELECT 
    COUNT(*) total_rows,
    COUNT(*)-COUNT(order_id) AS id_nullcount,
    COUNT(*)-COUNT(order_item_id) AS itemid_nullcount,
    COUNT(*)-COUNT(product_id) AS productid_nullcount,
    COUNT(*)-COUNT(seller_id) AS sellerid_nullcount,
    COUNT(*)-COUNT(shipping_limit_date) AS shipping_nullcount,
    COUNT(*)-COUNT(price) AS price_nullcount,
    COUNT(*)-COUNT(freight_value) AS freight_nullcount
FROM order_items

SELECT 
    order_id, 
    order_item_id, 
    COUNT(*) as combination_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

--GEOLOCATION TABLE
SELECT 
    COUNT(*) total_rows,
    COUNT(*)-COUNT(geolocation_zip_code_prefix) AS zipcode_nullcount,
    COUNT(*)-COUNT(geolocation_lat) AS lat_nullcount,
    COUNT(*)-COUNT(geolocation_lng) AS lng_nullcount,
    COUNT(*)-COUNT(geolocation_city) AS city_nullcount,
    COUNT(*)-COUNT(geolocation_state) AS state_nullcount
FROM geolocation

--ORDERS TABLE
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(order_id) AS id_nullcount,
    COUNT(*) - COUNT(customer_id) AS customer_id_nullcount,
    COUNT(*) - COUNT(order_status) AS order_status_nullcount,
    COUNT(*) - COUNT(order_purchase_timestamp) AS purchase_timestamp_nullcount,
    COUNT(*) - COUNT(order_approved_at) AS approved_at_nullcount,
    COUNT(*) - COUNT(order_delivered_carrier_date) AS carrier_date_nullcount,
    COUNT(*) - COUNT(order_delivered_customer_date) AS customer_date_nullcount,
    COUNT(*) - COUNT(order_estimated_delivery_date) AS estimated_delivery_nullcount,
    COUNT(order_id) - COUNT(DISTINCT order_id) AS id_duplicates
FROM orders;

--DISTINCT ORDER STATUS
SELECT DISTINCT(order_status)
FROM orders

--CHECK WHY APPROVED DATE IS NULL 
SELECT order_status,
order_approved_at
FROM orders
WHERE order_approved_at IS NULL

--CHECK WHY DELIVERED CARRIER DATE IS NULL 
SELECT order_status,
order_delivered_carrier_date
FROM orders
WHERE order_delivered_carrier_date IS NULL  

--CHECK WHY DELIVERED CUSTOMER DATE IS NULL 
SELECT order_status,
order_delivered_customer_date
FROM orders
WHERE order_delivered_customer_date IS NULL 

--ORDER_PAYMENTS TABLE
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(order_id) AS order_id_nullcount,
    COUNT(*) - COUNT(payment_sequential) AS sequential_nullcount,
    COUNT(*) - COUNT(payment_type) AS type_nullcount,
    COUNT(*) - COUNT(payment_installments) AS installments_nullcount,
    COUNT(*) - COUNT(payment_value) AS value_nullcount
FROM order_payments;

SELECT 
    order_id, 
    payment_sequential,
    COUNT(*) as combination_count
FROM order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;

--ORDER_REVIEWS
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(review_id) AS review_id_nullcount,
    COUNT(*) - COUNT(order_id) AS order_id_nullcount,
    COUNT(*) - COUNT(review_score) AS score_nullcount,
    COUNT(*) - COUNT(review_comment_title) AS comment_title_nullcount,
    COUNT(*) - COUNT(review_comment_message) AS comment_message_nullcount,
    COUNT(*) - COUNT(review_creation_date) AS creation_date_nullcount,
    COUNT(*) - COUNT(review_answer_timestamp) AS answer_timestamp_nullcount
FROM order_reviews;

--PRODUCT_CATEGORY_NAME_TRANSLATION
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(product_category_name) AS category_name_nullcount,
    COUNT(*) - COUNT(product_category_name_english) AS english_name_nullcount,
    COUNT(product_category_name)-COUNT(DISTINCT(product_category_name)) AS name_duplicates
FROM product_category_name_translation;

--PRODUCTS
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(product_id) AS product_id_nullcount,
    COUNT(*) - COUNT(product_category_name) AS category_name_nullcount,
    COUNT(*) - COUNT(product_name_length) AS name_length_nullcount,
    COUNT(*) - COUNT(product_description_length) AS description_length_nullcount,
    COUNT(*) - COUNT(product_photos_qty) AS photos_qty_nullcount,
    COUNT(*) - COUNT(product_weight_g) AS weight_nullcount,
    COUNT(*) - COUNT(product_length_cm) AS length_nullcount,
    COUNT(*) - COUNT(product_height_cm) AS height_nullcount,
    COUNT(*) - COUNT(product_width_cm) AS width_nullcount,
    COUNT(product_id)-COUNT(DISTINCT(product_id)) AS id_duplicates
FROM products;

--SELLERS TABLE
SELECT 
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(seller_id) AS seller_id_nullcount,
    COUNT(*) - COUNT(seller_zip_code_prefix) AS zip_code_prefix_nullcount,
    COUNT(*) - COUNT(seller_city) AS city_nullcount,
    COUNT(*) - COUNT(seller_state) AS state_nullcount,
    COUNT(seller_id)-COUNT(DISTINCT(seller_id)) AS id_duplicates
FROM sellers;

--CITY NAMES
SELECT customer_city
FROM customers
GROUP BY customer_city

--CHECK IF PRICE IS 0 OR NEGATIVE
SELECT price
FROM order_items
WHERE price<=0

--CHECK PAYMENT SEQUENCE AND TYPE PER ORDER_ID 
SELECT 
    order_id,
    payment_sequential,
    payment_type
FROM order_payments
GROUP BY 1,2,3

--DISTINCT PRODUCT CATEGORIES
SELECT product_category_name_english
FROM product_category_name_translation
GROUP BY product_category_name_english
LIMIT 71

--CHECK GEOLOCATION COORDINATES
SELECT *
FROM geolocation
WHERE 
    geolocation_lat > 5.27      -- Too far North
    OR geolocation_lat < -33.75    -- Too far South
    OR geolocation_lng > -34.79    -- Too far East
    OR geolocation_lng < -73.98

--TIME INVERSION CORRECTION
--WAS ORDER DELIVERED TO CUSTOMER BEFORE PURCHASE WAS DONE OR CARRIER WAS GIVEN
SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM orders
WHERE 
    --order_delivered_customer_date<order_delivered_carrier_date 
    --order_delivered_customer_date<order_purchase_timestamp 
    --order_delivered_customer_date<order_approved_at 
    --order_delivered_carrier_date<order_purchase_timestamp 

--CHECK SEPTEMBER INCOMPLETE DATA
SELECT
    MIN(order_purchase_timestamp) AS first_order_of_month,
    MAX(order_purchase_timestamp) AS last_order_of_month,
    EXTRACT(DAY FROM MAX(order_purchase_timestamp)) AS active_days_recorded
FROM orders
WHERE DATE_TRUNC('month',order_purchase_timestamp)='2018-09-01'

--CHECK OUTLIERS
--PRICE
WITH price_quartiles AS
(
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY price) AS q1,
        PERCENTILE_CONT(0.75)WITHIN GROUP (ORDER BY price) AS q3
    FROM order_items
),
iqr_bounds AS (
    SELECT 
        q1,
        q3,
        (q3-q1) AS iqr,
        q1-(1.5*(q3-q1)) AS lower_bound,
        q3+(1.5*(q3-q1)) AS upper_bound
    FROM price_quartiles
)

SELECT
    oi.order_id,
    oi.product_id,
    oi.price,
    ROUND((b.upper_bound)::NUMERIC,2) AS outlier_threshold
FROM order_items AS oi
CROSS JOIN iqr_bounds AS b
WHERE oi.price>b.upper_bound
ORDER BY oi.price DESC
LIMIT 20

--FREIGHT VALUE
SELECT 
    price,
    freight_value
FROM order_items
WHERE freight_value>price

--WHICH PRODUCT CATEGORIES HAVE HIGHER FREIGHT THAN PRICE
SELECT 
    pt.product_category_name_english AS product_category,
    COUNT(*) AS total_occurrences,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_item_price,
    ROUND(AVG(oi.freight_value)::NUMERIC, 2) AS avg_freight_cost,
    ROUND(AVG(p.product_weight_g), 0) AS avg_weight_grams
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation pt ON p.product_category_name = pt.product_category_name
WHERE oi.freight_value > oi.price
GROUP BY 1
ORDER BY total_occurrences DESC
LIMIT 10;

--PRODUCT WEIGHT G
WITH weight_quartiles AS
(
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY product_weight_g) AS q1,
        PERCENTILE_CONT(0.75)WITHIN GROUP (ORDER BY product_weight_g) AS q3
    FROM products
),
iqr_bounds AS (
    SELECT 
        q1,
        q3,
        (q3-q1) AS iqr,
        q1-(1.5*(q3-q1)) AS lower_bound,
        q3+(1.5*(q3-q1)) AS upper_bound
    FROM weight_quartiles
)

SELECT
    p.product_id,
    p.product_weight_g,
    ROUND((b.upper_bound)::NUMERIC,2) AS outlier_threshold
FROM products AS p
CROSS JOIN iqr_bounds AS b
WHERE p.product_weight_g>b.upper_bound
ORDER BY p.product_weight_g DESC
LIMIT 20

--DELIVERY DAYS
WITH delivery_duration AS (
    SELECT
        order_id,
        EXTRACT(DAY FROM (order_delivered_customer_date-order_purchase_timestamp))AS delivery_days
    FROM 
        orders
    WHERE 
        order_status='delivered' AND 
        order_delivered_customer_date IS NOT NULL AND 
        order_purchase_timestamp IS NOT NULL
), delivery_quartiles AS
(
    SELECT 
        PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY delivery_days) AS q1,
        PERCENTILE_CONT(0.75)WITHIN GROUP (ORDER BY delivery_days) AS q3
    FROM delivery_duration
),
iqr_bounds AS (
    SELECT 
        q1,
        q3,
        (q3-q1) AS iqr,
        q1-(1.5*(q3-q1)) AS lower_bound,
        q3+(1.5*(q3-q1)) AS upper_bound
    FROM delivery_quartiles
)

SELECT
    dd.order_id,
    dd.delivery_days,
    ROUND((b.upper_bound)::NUMERIC,2) AS outlier_threshold
FROM delivery_duration AS dd
CROSS JOIN iqr_bounds AS b
WHERE dd.delivery_days>b.upper_bound
ORDER BY dd.delivery_days DESC
LIMIT 20

--DISTINCT MACRO PRODUCT CATEGORIES
SELECT macro_product_category_name, COUNT(*) as total_products
FROM products_dim
GROUP BY 1
ORDER BY total_products DESC;

--DISTINCT YEAR
SELECT EXTRACT(YEAR FROM order_purchase_timestamp) AS year
FROM orders_fact
GROUP BY year

--CHECK PRODUCTS CATEGORIES UNDER UNCLASSIFIED MACRO CATEGORY
SELECT 
    COALESCE(p.macro_product_category_name,'Unclassified') AS product_category,
    p.product_category_name
FROM orders_fact AS o
LEFT JOIN order_items_dim AS ot ON ot.order_id=o.order_id
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
WHERE COALESCE(p.macro_product_category_name,'Unclassified') ='Unclassified'
GROUP BY COALESCE(p.macro_product_category_name,'Unclassified'),p.product_category_name

