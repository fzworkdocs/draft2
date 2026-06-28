SELECT * FROM orders_fact
SELECT * FROM order_items_fact
SELECT * FROM order_payments_fact
SELECT * FROM order_reviews_fact
SELECT * FROM products_dim
SELECT * FROM sellers_dim
SELECT * FROM customers_dim
SELECT * FROM geolocation_dim

--ORDER VALUE BY PRODUCT CATEGORY
SELECT 
    p.macro_product_category_name AS product_category,
    COUNT(DISTINCT ot.order_id) AS total_orders
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY total_orders DESC

--PRODUCT CATEGORY BY REVENUE
SELECT 
    p.macro_product_category_name AS product_category,
    SUM(ot.gross_sales) AS total_sales
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY total_sales DESC

--PRODUCT CATEGORY BY GROSS PROFIT
SELECT 
    p.macro_product_category_name AS product_category,
    SUM(ot.gross_profit) AS total_gross_profits
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY total_gross_profits DESC

--PRODUCT CATEGORY BY NET PROFIT
SELECT 
    p.macro_product_category_name AS product_category,
    SUM(ot.net_profit) AS total_net_profits
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY total_net_profits DESC

--WHY TECHNOLOGY AND ELECTRONICS HAVE HIGH SALES BUT LOWER PROFITS
--COGS BY PRODUCT CATEGORY
SELECT 
    p.macro_product_category_name AS product_category,
    SUM(ot.total_cogs) AS total_cogs
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY total_cogs DESC

--FREIGHT COST BY PRODUCT CATEGORY
SELECT 
    p.macro_product_category_name AS product_category,
    SUM(ot.total_freight) AS total_freight
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY total_freight DESC

--PROFIT MARGIN BY PRODUCT CATEGORY
SELECT 
    p.macro_product_category_name AS product_category,
    ROUND(SUM(ot.net_profit)/NULLIF(SUM(ot.gross_sales),0)*100,1) AS profit_margin_pct
FROM order_items_fact AS ot
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY p.macro_product_category_name
ORDER BY profit_margin_pct DESC

--AVERAGE DELIVERY DAYS TAKEN BY PRODUCT CATEGORY check
SELECT 
    p.macro_product_category_name AS product_category,
    SUM(ot.total_freight) AS total_freight,
    ROUND(AVG(o.delivery_days)::NUMERIC,0) AS avg_delivery_days,
    ROUND((PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY o.delivery_days))::NUMERIC,2) AS median_delivery
FROM orders_fact AS o
LEFT JOIN order_items_dim AS ot ON ot.order_id=o.order_id
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
GROUP BY COALESCE(p.macro_product_category_name,'Unclassified')
ORDER BY ROUND(AVG(o.delivery_days)::NUMERIC,0) DESC

--COUNT OF ORDERS IN EACH PRODUCT CATEGORY IN THE VERY SLOW DELIVERY DAYS CATEGORY
WITH delays AS (
    SELECT order_id,
    CASE
        WHEN delivery_days<=7 THEN 'Fast'
        WHEN delivery_days<=13 THEN 'Medium'
        WHEN delivery_days<=21 THEN 'Slow'
        WHEN delivery_days<=30 THEN 'Very Slow'
        ELSE 'Extreme Delay(30+ days)'
    END AS delay_category
FROM orders_fact
)
SELECT 
    COALESCE(p.macro_product_category_name,'Unclassified') AS product_category,
    d.delay_category,
    COUNT(DISTINCT d.order_id) AS total_orders
FROM delays AS d
LEFT JOIN order_items_dim AS ot ON ot.order_id=d.order_id
LEFT JOIN products_dim AS p ON p.product_id=ot.product_id
WHERE delay_category='Very Slow' OR delay_category='Extreme Delay(30+ days)'
GROUP BY COALESCE(p.macro_product_category_name,'Unclassified'),d.delay_category
ORDER BY  COUNT(*) DESC

--COHORT ANALYSIS
CREATE OR REPLACE VIEW cohort_analysis AS

WITH customer_order AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS order_month
    FROM orders_fact o
    INNER JOIN customers_dim c
        ON o.customer_id = c.customer_id
    WHERE
        (
            o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2017-09-01'
            OR
            o.order_purchase_timestamp BETWEEN '2018-01-01' AND '2018-09-01'
        )
        AND o.order_status = 'delivered'
),

first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_order
    GROUP BY customer_unique_id
),

indexing AS (
    SELECT
        co.customer_unique_id,
        fp.cohort_month,
        (
            EXTRACT(YEAR FROM AGE(co.order_month, fp.cohort_month)) * 12
            +
            EXTRACT(MONTH FROM AGE(co.order_month, fp.cohort_month))
        ) AS cohort_index
    FROM customer_order co
    JOIN first_purchase fp
        ON fp.customer_unique_id = co.customer_unique_id
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_customers
    FROM indexing
    WHERE cohort_index = 0
    GROUP BY cohort_month
)

SELECT
    ind.cohort_month,
    ind.cohort_index,
    COUNT(DISTINCT ind.customer_unique_id) AS total_customers,
    cz.cohort_customers,
    ROUND(
        COUNT(DISTINCT ind.customer_unique_id) * 100.0
        / NULLIF(cz.cohort_customers, 0),
        1
    ) AS retention_rate
FROM indexing ind
JOIN cohort_size cz
    ON cz.cohort_month = ind.cohort_month
WHERE ind.cohort_index<4
GROUP BY
    ind.cohort_month,
    ind.cohort_index,
    cz.cohort_customers
ORDER BY
    ind.cohort_month,
    ind.cohort_index;

--FREIGHT DENSITY ANALYSIS

CREATE VIEW freight_density_analysis AS

WITH density_data AS (

    SELECT
        p.product_id,
        p.macro_product_category_name AS product_category,

        p.product_weight_g,

        (
            p.product_length_cm *
            p.product_height_cm *
            p.product_width_cm
        ) AS product_volume_cm3,

        ot.total_freight,
        ot.gross_sales,
        ot.net_profit,
        o.delivery_days

    FROM products_dim p
    INNER JOIN order_items_fact ot
        ON ot.product_id = p.product_id
    INNER JOIN orders_fact o
        ON o.order_id = ot.order_id
),

density_calc AS (

    SELECT *,

        (product_weight_g::NUMERIC / NULLIF(product_volume_cm3,0)) AS freight_density

    FROM density_data
),

density_segments AS (

    SELECT *,

        CASE
            WHEN freight_density < 0.02 THEN 'Low Density (Bulky)'
            WHEN freight_density < 0.08 THEN 'Medium Density'
            ELSE 'High Density (Compact)'
        END AS density_category

    FROM density_calc
)

SELECT

    product_category,
    density_category,

    COUNT(*) AS total_items,

    ROUND(CAST(AVG(total_freight) AS NUMERIC),1) AS avg_freight_cost,

    ROUND(CAST(AVG(gross_sales) AS NUMERIC),1) AS avg_sales,

    ROUND(
        CAST(
            SUM(net_profit) * 100.0 /
            NULLIF(SUM(gross_sales),0)
        AS NUMERIC),
        1
    ) AS weighted_profit_margin_pct,

    ROUND(CAST(AVG(delivery_days) AS NUMERIC),1) AS avg_delivery_days

FROM density_segments

GROUP BY
    product_category,
    density_category

--CUSTOMER SEGMENTATION
--BY SPENDING AMOUNT

CREATE VIEW customer_value_segment AS

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
GROUP BY customer_value

--BY PURCHASE FREQUENCY

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

SELECT 
    purchase_freq_segment,
    COUNT(DISTINCT customer_unique_id) AS total_customers,
    SUM(total_sales) AS total_sales,
    SUM(total_profit) AS total_profit
FROM segments
GROUP BY purchase_freq_segment
ORDER BY total_customers DESC

--PROFIT MARGIN 2017 JAN-AUG VS 2018 JAN-AUG

SELECT

    ROUND(
        (
            SUM(
                CASE
                    WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
                     AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                    THEN ot.net_profit
                    ELSE 0
                END
            ) * 100.0
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
                     AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                    THEN ot.gross_sales
                    ELSE 0
                END
            ),
            0
        ),
        1
    ) AS profit_margin_2017_jan_aug,

    ROUND(
        (
            SUM(
                CASE
                    WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
                     AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                    THEN ot.net_profit
                    ELSE 0
                END
            ) * 100.0
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
                     AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                    THEN ot.gross_sales
                    ELSE 0
                END
            ),
            0
        ),
        1
    ) AS profit_margin_2018_jan_aug

FROM order_items_fact ot
INNER JOIN orders_fact o
    ON o.order_id = ot.order_id;

--AOV 2017 JAN-AUG VS 2018 JAN-AUG

SELECT

    ROUND(
        SUM(
            CASE
                WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
                 AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                THEN ot.gross_sales
                ELSE 0
            END
        )
        /
        NULLIF(
            COUNT(
                DISTINCT CASE
                    WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2017
                     AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                    THEN o.order_id
                END
            ),
            0
        ),
        1
    ) AS aov_2017_jan_aug,

    ROUND(
        SUM(
            CASE
                WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
                 AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                THEN ot.gross_sales
                ELSE 0
            END
        )
        /
        NULLIF(
            COUNT(
                DISTINCT CASE
                    WHEN EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
                     AND EXTRACT(MONTH FROM o.order_purchase_timestamp) <= 8
                    THEN o.order_id
                END
            ),
            0
        ),
        1
    ) AS aov_2018_jan_aug

FROM orders_fact o
INNER JOIN order_items_fact ot
    ON ot.order_id = o.order_id;