-- 1. Create Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix VARCHAR(10),
    customer_city VARCHAR(100),
    customer_state CHAR(2)
);

-- 2. Create Order Items Table
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP WITHOUT TIME ZONE,
    price NUMERIC(10, 2),
    freight_value NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id) -- Composite primary key as order_id can have multiple items
);

-- 3. Create Geolocation Table
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(10),
    geolocation_lat NUMERIC(10, 8) NOT NULL,
    geolocation_lng NUMERIC(11, 8) NOT NULL,
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2)
);

-- 4. Create Orders Table
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(50),
    order_purchase_timestamp TIMESTAMP WITHOUT TIME ZONE,
    order_approved_at TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_carrier_date TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_customer_date TIMESTAMP WITHOUT TIME ZONE,
    order_estimated_delivery_date TIMESTAMP WITHOUT TIME ZONE
);

-- 5. Create Order Payments Table
CREATE TABLE order_payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_sequential) -- Composite primary key as an order can have multiple sequential payment steps
);

-- 6. Create Order Reviews Table
CREATE TABLE order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT CHECK (review_score BETWEEN 1 AND 5), -- Constrains scores to valid 1-5 star ratings
    review_comment_title VARCHAR(255),
    review_comment_message TEXT, -- Uses TEXT to safely store long or multi-line user feedback
    review_creation_date TIMESTAMP WITHOUT TIME ZONE,
    review_answer_timestamp TIMESTAMP WITHOUT TIME ZONE,
    PRIMARY KEY (review_id, order_id) -- Composite key because a single review can occasionally span multiple orders
);

-- 7. Create Product Category Name Translation Table
CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
);

-- 8. Create Products Table
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INT,               -- Length of name in characters
    product_description_length INT,        -- Length of description in characters
    product_photos_qty INT,                -- Count of product photos
    product_weight_g INT,                  -- Weight in grams (all values are integers)
    product_length_cm INT,                 -- Length in centimeters (all values are integers)
    product_height_cm INT,                 -- Height in centimeters (all values are integers)
    product_width_cm INT                   -- Width in centimeters (all values are integers)
);

-- 9. Create Sellers Table
CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),    -- Keeps text format to seamlessly match customer and geolocation zips
    seller_city VARCHAR(100),
    seller_state CHAR(2)                   -- Optimized for standard 2-letter state abbreviations
);