--ADD DELIVERY DAYS COLUMN IN ORDERS_FACT
ALTER TABLE orders_fact
ADD COLUMN delivery_days INT

UPDATE orders_fact
SET delivery_days=
    CASE
        WHEN order_status = 'delivered'
            AND order_delivered_customer_date IS NOT NULL
            THEN (order_delivered_customer_date::DATE
          - order_purchase_timestamp::DATE)
        ELSE NULL
    END 

--ADD DELIVERY SPEED CATEGORY COLUMN IN ORDERS_FACT
ALTER TABLE orders_fact
ADD COLUMN delay_category VARCHAR(30);

UPDATE orders_fact
SET delay_category =
    CASE
        WHEN delivery_days IS NULL THEN 'Not Delivered'
        WHEN delivery_days <= 7 THEN 'Fast'
        WHEN delivery_days <= 13 THEN 'Medium'
        WHEN delivery_days <= 21 THEN 'Slow'
        WHEN delivery_days <= 30 THEN 'Very Slow'
        ELSE 'Extreme Delay (30+ days)'
    END;

--fix order status cancelled in orders fact
UPDATE orders_fact
SET order_status='cancelled'
WHERE order_status='canceled'

--ADD MACRO CATEGORY COLUMN IN PRODUCTS
ALTER TABLE products_dim
ADD COLUMN macro_product_category_name VARCHAR(50)

UPDATE products_dim
SET macro_product_category_name=CASE 
    -- 1. TECHNOLOGY & ELECTRONICS
    WHEN product_category_name IN (
        'air_conditioning', 'audio', 'cine_photo', 'computers', 
        'computers_accessories', 'consoles_games', 'electronics', 
        'fixed_telephony', 'pc_gamer', 'tablets_printing_image', 
        'telephony', 'watches_gifts'
    ) THEN 'Technology & Electronics'
    
    -- 2. HOME & LIVING
    WHEN product_category_name IN (
        'bed_bath_table', 'furniture_bedroom', 'furniture_decor', 
        'furniture_living_room', 'furniture_mattress_and_upholstery', 
        'home_appliances', 'home_appliances_2', 'home_comfort_2', 
        'home_confort', 'home_construction', 'housewares', 
        'kitchen_dining_laundry_garden_furniture', 'office_furniture', 
        'small_appliances', 'small_appliances_home_oven_and_coffee', 'la_cuisine'
    ) THEN 'Home & Living'
    
    -- 3. FASHION & APPAREL
    WHEN product_category_name IN (
        'fashion_bags_accessories', 'fashion_childrens_clothes', 
        'fashion_female_clothing', 'fashion_male_clothing', 
        'fashion_shoes', 'fashion_sport', 'fashion_underwear_beach', 
        'luggage_accessories'
    ) THEN 'Fashion & Apparel'
    
    -- 4. HEALTH, BEAUTY & FAMILY
    WHEN product_category_name IN (
        'baby', 'diapers_and_hygiene', 'health_beauty', 'perfumery'
    ) THEN 'Health, Beauty & Family'
    
    -- 5. LIFESTYLE & LEISURE
    WHEN product_category_name IN (
        'art', 'arts_and_craftmanship', 'books_general_interest', 
        'books_imported', 'books_technical', 'cds_dvds_musicals', 
        'christmas_supplies', 'cool_stuff', 'dvds_blu_ray', 
        'music', 'musical_instruments', 'party_supplies', 
        'signaling_and_games', 'sports_leisure', 'toys', 'flowers','pet_shop'
    ) THEN 'Lifestyle & Leisure'
    
    -- 6. TOOLS, HARDWARE & AUTO
    WHEN product_category_name IN (
        'auto', 'construction_tools_construction', 'construction_tools_lights', 
        'construction_tools_safety', 'costruction_tools_garden', 
        'costruction_tools_tools', 'garden_tools','security_and_services',
        'signaling_and_security'
    ) THEN 'Tools, Hardware & Auto'
    
    -- 7. CONSUMABLES & COMMERCIAL
    WHEN product_category_name IN (
        'agro_industry_and_commerce', 'drinks', 'food', 'food_drink', 
        'industry_commerce_and_business', 'market_place', 'stationery'
    ) THEN 'Consumables & Commercial'
    
    ELSE 'Unclassified'
END;

--FIX MACRO CATEGORY NULLS
UPDATE products_dim
SET macro_product_category_name = 'Unclassified'
WHERE 
    macro_product_category_name = '' OR
    macro_product_category_name IS NULL;

--FIX TYPO IN PRODUCT CATEGORY COLUMN IN PRODUCTS
UPDATE products_dim
SET product_category_name='fashion_female_clothing'
WHERE product_category_name='fashio_female_clothing'

ALTER TABLE  order_payments_dim
RENAME TO order_payments_fact

ALTER TABLE order_reviews_dim
RENAME TO order_reviews_fact

ALTER TABLE customers_dim
ADD COLUMN customer_region VARCHAR(50)

UPDATE customers_dim
SET customer_region =
CASE
    WHEN customer_state IN ('AC','AP','AM','PA','RO','RR','TO')
        THEN 'North'

    WHEN customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE')
        THEN 'Northeast'

    WHEN customer_state IN ('DF','GO','MT','MS')
        THEN 'Central-West'

    WHEN customer_state IN ('ES','MG','RJ','SP')
        THEN 'Southeast'

    WHEN customer_state IN ('PR','RS','SC')
        THEN 'South'

    ELSE 'Unknown'
END;

ALTER TABLE sellers_dim
ADD COLUMN seller_region VARCHAR(20);

UPDATE sellers_dim
SET seller_region =
CASE
    WHEN seller_state IN ('AC','AP','AM','PA','RO','RR','TO')
        THEN 'North'

    WHEN seller_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE')
        THEN 'Northeast'

    WHEN seller_state IN ('DF','GO','MT','MS')
        THEN 'Central-West'

    WHEN seller_state IN ('ES','MG','RJ','SP')
        THEN 'Southeast'

    WHEN seller_state IN ('PR','RS','SC')
        THEN 'South'

    ELSE 'Unknown'
END;

CREATE VIEW customer2_value_segments AS
WITH aov AS (
    SELECT 
        c.customer_unique_id,
        SUM(totals.order_total_sales) AS order_total_sales,
        SUM(totals.order_total_profits) AS order_total_profits,
        ROUND(AVG(totals.order_total_sales),0) AS avg_order_value
    FROM (
        SELECT 
            o.order_id,
            o.customer_id,
            SUM(ot.gross_sales) AS order_total_sales,
            SUM(ot.gross_profit) AS order_total_profits
        FROM orders_fact o
        INNER JOIN order_items_fact ot 
            ON ot.order_id = o.order_id
        GROUP BY o.order_id, o.customer_id
    ) totals
    LEFT JOIN customers_dim c 
        ON c.customer_id = totals.customer_id
    WHERE c.customer_unique_id IS NOT NULL
    GROUP BY c.customer_unique_id
),

ranks AS (
    SELECT 
        customer_unique_id,
        order_total_sales,
        order_total_profits,
        avg_order_value,
        NTILE(100) OVER (ORDER BY avg_order_value) AS percentile_rank
    FROM aov
),

value_segments AS (
    SELECT
        customer_unique_id,
        order_total_sales,
        order_total_profits,
        avg_order_value,
        CASE
            WHEN percentile_rank <= 50 THEN 'Low Value'
            WHEN percentile_rank <= 80 THEN 'Medium Value'
            ELSE 'High Value'
        END AS customer_value
    FROM ranks
)
SELECT
    customer_value,
    COUNT(customer_unique_id) AS customer_count,
    ROUND(SUM(order_total_sales),1) AS total_sales,
    ROUND(SUM(order_total_profits),1) AS total_profit,
    ROUND(AVG(order_total_sales),1) AS avg_customer_sales
FROM value_segments
GROUP BY customer_value;

CREATE VIEW customer_purchasefreq_segments AS
WITH customer_orders AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(ot.gross_sales) AS total_sales,
        SUM(ot.gross_profit) AS total_profit
    FROM customers_dim c
    INNER JOIN orders_fact o 
        ON o.customer_id = c.customer_id
    INNER JOIN order_items_fact ot 
        ON ot.order_id = o.order_id
    GROUP BY c.customer_unique_id
),

segments AS (
    SELECT 
        customer_unique_id,
        total_orders,
        total_sales,
        total_profit,
        CASE 
            WHEN total_orders = 1 THEN 'One-Time'
            WHEN total_orders BETWEEN 2 AND 5 THEN 'Repeat'
            ELSE 'Loyal'
        END AS purchase_freq_segment
    FROM customer_orders
)

SELECT *
FROM segments;
