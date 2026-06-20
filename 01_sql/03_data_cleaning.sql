--CREATE PRODUCT DIMENSION TABLE
CREATE TABLE products_dim AS
SELECT
    p.product_id,
    COALESCE(pt.product_category_name_english,'Unclassified') AS product_category_name, 
    COALESCE(p.product_weight_g,(SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY product_weight_g)FROM products)) AS product_weight_g,  -- Catalog median weight is ~700g
    COALESCE(p.product_length_cm,(SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY product_length_cm)FROM products)) AS product_length_cm, -- Catalog median length is ~25cm
    COALESCE(p.product_height_cm,(SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY product_height_cm)FROM products))AS product_height_cm,  -- Catalog median height is ~13cm
    COALESCE(p.product_width_cm, (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY product_width_cm) FROM products)) AS product_width_cm
FROM products AS p
LEFT JOIN product_category_name_translation AS pt
    ON pt.product_category_name=p.product_category_name

--CREATE CUSTOMERS DIMENSION TABLE
CREATE TABLE customers_dim AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM customers

--CREATE GEOLOCATION DIMENSION TABLE
CREATE TABLE geolocation_dim AS
SELECT 
    geolocation_zip_code_prefix,

    CASE 
        WHEN geolocation_lat > 5.27 OR geolocation_lat < -33.75 THEN NULL
        ELSE geolocation_lat
    END AS geolocation_lat,
    CASE 
        WHEN geolocation_lng > -34.79 OR geolocation_lng < -73.98 THEN NULL
        ELSE geolocation_lng
    END AS geolocation_lng,

    geolocation_city,
    geolocation_state
FROM geolocation

--CREATE SELLERS DIMENSION TABLE
CREATE TABLE sellers_dim AS
SELECT 
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM sellers







