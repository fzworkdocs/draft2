--CREATE ORDERS FACT TABLE
CREATE TABLE orders_fact AS 

WITH cleaned_date AS(
    SELECT o.*,
        CASE 
            WHEN o.order_status IN ('delivered','shipped','approved','processing','invoiced') 
                AND o.order_approved_at IS NULL 
                THEN o.order_purchase_timestamp
            ELSE o.order_approved_at 
        END AS cleaned_approved_at
    FROM orders o
)

SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,

   --CLEAN APPROVED AT
   cleaned_approved_at AS order_approved_at,
        
    --CLEAN CARRIER DATE
    CASE 
        WHEN order_status IN ('delivered','shipped') 
            AND order_delivered_carrier_date IS NULL 
            THEN COALESCE(cleaned_approved_at, order_purchase_timestamp)

        WHEN order_status IN ('delivered','shipped')  
            AND order_delivered_customer_date IS NOT NULL
            AND order_delivered_carrier_date IS NOT NULL 
            AND order_delivered_customer_date::DATE < order_delivered_carrier_date::DATE 
            THEN COALESCE(cleaned_approved_at, order_purchase_timestamp) 

        WHEN order_status IN ('delivered','shipped')  
            AND order_delivered_carrier_date IS NOT NULL 
            AND order_delivered_carrier_date::DATE < order_purchase_timestamp::DATE
            THEN COALESCE(cleaned_approved_at, order_purchase_timestamp) 
        ELSE order_delivered_carrier_date
    END AS order_delivered_carrier_date, 
    
    -- CLEAN DELIVERED CUSTOMER DATE
    CASE 
        WHEN order_status = 'delivered' 
            AND order_delivered_customer_date IS NULL 
            THEN order_estimated_delivery_date 

        WHEN order_status = 'delivered' 
            AND order_delivered_customer_date::DATE < 
                COALESCE(cleaned_approved_at::DATE,order_purchase_timestamp::DATE)
            THEN order_estimated_delivery_date

         WHEN order_status = 'delivered' 
            AND order_delivered_customer_date::DATE < order_purchase_timestamp::DATE
            THEN order_estimated_delivery_date
        ELSE order_delivered_customer_date
    END AS order_delivered_customer_date, 

    order_estimated_delivery_date,

    -- ORDER APPROVAL STATUS DIMENSION
    CASE
        WHEN cleaned_approved_at IS NULL 
            AND order_status IN ('canceled','unavailable') 
            THEN 'Not Approved (Cancelled/Unavailable)'
        WHEN cleaned_approved_at IS NULL 
            AND order_status = 'created' 
            THEN 'Pending Approval'
        ELSE 'Approved'
    END AS order_approval_status
FROM cleaned_date 


--CREATE ORDER PAYMENTS FACT TABLE
CREATE TABLE order_payments_fact AS
SELECT
    op.order_id,
    op.payment_sequential,
    op.payment_type,
    COALESCE(op.payment_installments,0) AS payment_installments,
    COALESCE(op.payment_value,0) AS payment_value
FROM order_payments AS op


CREATE TABLE order_payments_fact AS
SELECT
    op.order_id,
    op.payment_sequential,
    op.payment_type,
    COALESCE(op.payment_installments,0) AS payment_installments,
    COALESCE(op.payment_value,0) AS payment_value,
    COALESCE(clean_ot.estimated_payment,0) AS estimated_payment,
    COALESCE(clean_op.paid_value,0) AS paid_value,
    ROUND((COALESCE(clean_op.paid_value,0)-COALESCE(clean_ot.estimated_payment,0))::NUMERIC,2) AS discrepancy
FROM order_payments AS op
LEFT JOIN (
    SELECT order_id,
    SUM(price)+SUM(freight_value) AS estimated_payment
    FROM order_items
    GROUP BY order_id
) AS clean_ot ON clean_ot.order_id=op.order_id
LEFT JOIN (
    SELECT 
        order_id,
        SUM(payment_value) AS paid_value
    FROM order_payments
    GROUP BY order_id
) AS clean_op ON clean_op.order_id = op.order_id

--CREATE ORDER REVIEWS FACT TABLE
CREATE TABLE order_reviews_fact AS
SELECT 
    review_id,
    order_id,
    review_score,
    review_creation_date
FROM order_reviews

--CREATE ORDER ITEMS FACT TABLE
CREATE TABLE order_items_fact AS
WITH item_margins AS (
    SELECT
    ot.order_id,
    ot.order_item_id,
    ot.product_id,
    ot.seller_id,
    ot.shipping_limit_date,
     -- FINANCIAL METRICS
    COALESCE(ot.price, 0) AS gross_sales,
    COALESCE(ot.freight_value, 0) AS total_freight,
    CASE 
        -- TIER 1: Electronics, Tech & High-Value Gadgets (Low 15% Margin / 85% Cost)
        WHEN pc.product_category_name_english IN ('air_conditioning', 'audio', 'cine_photo', 'computers', 
                                'computers_accessories', 'consoles_games', 'electronics', 
                                'fixed_telephony', 'pc_gamer', 'tablets_printing_image', 
                                'telephony', 'watches_gifts')
        THEN 0.15
        -- TIER 2: Apparel, Beauty, Baby & Personal Luxury (High 60% Margin / 40% Cost)
        WHEN pc.product_category_name_english IN (
                                'baby', 'diapers_and_hygiene', 'fashion_bags_accessories', 
                                'fashion_childrens_clothes', 'fashion_female_clothing', 
                                'fashion_male_clothing', 'fashion_shoes', 'fashion_sport', 
                                'fashion_underwear_beach', 'health_beauty', 'perfumery') 
        THEN 0.60
        -- TIER 3: Heavy Capital Goods, Machinery & Large Furniture (Medium-Low 25% Margin / 75% Cost)
        WHEN pc.product_category_name_english IN (
                                'agro_industry_and_commerce', 'furniture_bedroom', 'furniture_decor', 
                                'furniture_living_room', 'furniture_mattress_and_upholstery', 
                                'home_appliances', 'home_appliances_2', 'industry_commerce_and_business', 
                                'kitchen_dining_laundry_garden_furniture', 'office_furniture')
        THEN 0.25
        -- TIER 4: Default Retail Goods (Standard 35% Margin / 65% Cost)
        ELSE 0.35
    END AS margin_ratio
FROM order_items ot
LEFT JOIN products pt ON pt.product_id=ot.product_id
LEFT JOIN product_category_name_translation AS pc ON pc.product_category_name=pt.product_category_name)

SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    gross_sales,
    total_freight,
    ROUND((gross_sales * (1 - margin_ratio))::NUMERIC,2) AS total_cogs,
    ROUND((gross_sales * margin_ratio)::NUMERIC,2) AS gross_profit,
    ROUND(((gross_sales * margin_ratio) - total_freight)::NUMERIC,2) AS net_profit,
    ROUND(((((gross_sales * margin_ratio) - total_freight)/ NULLIF(gross_sales,0))* 100)::NUMERIC,2) AS profit_margin_pct
FROM item_margins