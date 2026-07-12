# %% Correlation between delivery days and profit margin
import pandas as pd
from sqlalchemy import create_engine

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
    o.delivery_days,
    ot.profit_margin_pct
FROM orders_fact o
INNER JOIN order_items_fact ot ON ot.order_id=o.order_id
"""
df=pd.read_sql(query,engine)

corr=df[['delivery_days','profit_margin_pct']].corr()
print(corr)

# %% Regression for delivery days and profit margin
import pandas as pd
from sqlalchemy import create_engine
from sklearn.linear_model import LinearRegression

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
    o.delivery_days,
    ot.profit_margin_pct
FROM orders_fact o
INNER JOIN order_items_fact ot ON ot.order_id=o.order_id
WHERE o.delivery_days IS NOT NULL
"""
df=pd.read_sql(query,engine)

x=df[['delivery_days']]
y=df['profit_margin_pct']

model=LinearRegression()
model.fit(x,y)

print("Intercept:",model.intercept_)
print("Coefficient:",model.coef_[0])
print("R2",model.score(x,y))

# %% Regression for freight cost and profit margin
import pandas as pd
from sqlalchemy import create_engine
from sklearn.linear_model import LinearRegression

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
    total_freight,
    profit_margin_pct
FROM order_items_fact 
WHERE total_freight IS NOT NULL
"""
df=pd.read_sql(query,engine)

x=df[['total_freight']]
y=df['profit_margin_pct']

model=LinearRegression()
model.fit(x,y)

print("Intercept:",model.intercept_)
print("Coefficient:",model.coef_[0])
print("R2",model.score(x,y))

# %% Regression for cogs and profit margin
import pandas as pd
from sqlalchemy import create_engine
from sklearn.linear_model import LinearRegression

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
    total_cogs,
    profit_margin_pct
FROM order_items_fact 
WHERE total_freight IS NOT NULL
"""
df=pd.read_sql(query,engine)

x=df[['total_cogs']]
y=df['profit_margin_pct']

model=LinearRegression()
model.fit(x,y)

print("Intercept:",model.intercept_)
print("Coefficient:",model.coef_[0])
print("R2",model.score(x,y))

# %%BAD SELLERS CONTRIBUTING TO LOW MARGIN PRODUCTS?
import pandas as pd
from sqlalchemy import create_engine

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
    seller_id,
    product_id,
    gross_sales,
    gross_profit,
    total_freight
FROM order_items_fact 
"""
df=pd.read_sql(query,engine)

seller=df.groupby("seller_id").agg(
    sales=("gross_sales","sum"),
    freight=("total_freight","sum")
)

seller["freight_pct"]=seller["freight"]/seller["sales"]*100

seller["freight_segment"]=pd.cut(
    seller["freight_pct"].rank(pct=True),
    bins=[0, 0.3, 0.7, 1],
    labels=[
        "Low Freight Cost",
        "Medium Freight Cost",
        "High Freight Cost"],
    include_lowest=True
)

products=df.groupby("product_id").agg(
    sales=("gross_sales","sum"),
    profit=("gross_profit","sum")
)

products["margin"]=products["profit"]/products["sales"]*100

products["margin_segment"]=pd.cut(
    products["margin"].rank(pct=True),
    bins=[0, 0.3, 0.7, 1],
    labels=[
        "Low Margin",
        "Medium Margin",
        "High Margin"],
    include_lowest=True
)

analysis=df.merge(
    seller[["freight_segment"]],
    on="seller_id"
)

analysis=analysis.merge(
    products[["margin_segment"]],
    on="product_id"
)

result_pct=pd.crosstab(
    analysis["freight_segment"],
    analysis["margin_segment"],
    normalize="index"
)*100

print(result_pct.round(1))

# %% ARE HIGH VALUE CUSTOMERS MAJORLY PURCHASING HIGH MARGIN PRODUCTS
import pandas as pd
from sqlalchemy import create_engine

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
    c.customer_unique_id,
    ot.product_id,
    ot.gross_sales,
    ot.gross_profit
FROM order_items_fact ot
INNER JOIN orders_fact o ON o.order_id=ot.order_id
INNER JOIN customers_dim c ON c.customer_id=o.customer_id
WHERE 
    (o.order_purchase_timestamp BETWEEN '2017-01-01' AND '2017-08-31') OR
    (o.order_purchase_timestamp BETWEEN '2018-01-01' AND '2018-08-31')
"""
df=pd.read_sql(query,engine)

customers=df.groupby("customer_unique_id").agg(
    sales=("gross_sales","sum"),
    profit=("gross_profit","sum"),
    orders=("product_id","count")
)

customers["customer_segment"]=pd.cut(
    customers["sales"].rank(pct=True),
    bins=[0, 0.3, 0.7, 1],
    labels=[
        "Low value",
        "Medium Value",
        "High Value"],
    include_lowest=True
)

products=df.groupby("product_id").agg(
    sales=("gross_sales","sum"),
    profit=("gross_profit","sum")
)

products["margin"]=products["profit"]/products["sales"]*100

products["margin_segment"]=pd.cut(
    products["margin"].rank(pct=True),
    bins=[0, 0.3, 0.7, 1],
    labels=[
        "Low Margin",
        "Medium Margin",
        "High Margin"],
    include_lowest=True
)

analysis=df.merge(
    customers[["customer_segment"]],
    on="customer_unique_id"
)

analysis=analysis.merge(
    products[["margin_segment"]],
    on="product_id"
)

result_pct=pd.crosstab(
    analysis["customer_segment"],
    analysis["margin_segment"],
    normalize="index"
)*100

print(result_pct.round(1))

# %% DOES HIGH FREIGHT COST % LEAD TO LOWER REVIEW SCORE

import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query = """
SELECT
    o.order_id,
    ot.gross_sales,
    ot.total_freight,
    r.review_score
FROM orders_fact o
INNER JOIN order_items_fact ot
    ON o.order_id = ot.order_id
INNER JOIN order_reviews_fact r
    ON o.order_id = r.order_id
WHERE r.review_score IS NOT NULL
"""

df = pd.read_sql(query, engine)

# Freight Cost %
df["freight_pct"] = (
    df["total_freight"] /
    df["gross_sales"]
) * 100

# Remove invalid rows
df = df[df["gross_sales"] > 0]

# Segment into Low/Medium/High freight %
df["freight_segment"] = pd.qcut(
    df["freight_pct"],
    q=3,
    labels=[
        "Low Freight %",
        "Medium Freight %",
        "High Freight %"
    ]
)

result = (
    df.groupby("freight_segment")
      .agg(
          avg_review_score=("review_score", "mean"),
          avg_freight_pct=("freight_pct", "mean"),
          orders=("order_id", "count")
      )
)

print(result.round(2))
# %% WHICH PRODUCT CATEGORIES DO CUSTOMER SEGMENTS PREFER TO PURCHASE COMPARING USING REVENUE SHARE %
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
   "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query = """
SELECT
    c.customer_value_segment,
    p.macro_product_category_name AS product_category,
    ot.gross_sales,
    ot.gross_profit
FROM order_items_fact ot

INNER JOIN orders_fact o
    ON ot.order_id = o.order_id

INNER JOIN customers_dim c
    ON o.customer_id = c.customer_id

INNER JOIN products_dim p
    ON ot.product_id = p.product_id

WHERE c.customer_value_segment IS NOT NULL
"""

df = pd.read_sql(query, engine)

#Aggregate by Customer Segment and Product Category
product_mix = (
    df.groupby(
        ["customer_value_segment", "product_category"]
    )
    .agg(
        revenue=("gross_sales", "sum"),
        profit=("gross_profit", "sum"),
        orders=("gross_sales", "count")
    )
    .reset_index()
)

#Revenue Share within Each Customer Segment
product_mix["revenue_share"] = (
    product_mix["revenue"]
    /
    product_mix.groupby("customer_value_segment")["revenue"].transform("sum")
) * 100

#Rank Categories
product_mix["rank"] = (
    product_mix.groupby("customer_value_segment")["revenue_share"]
    .rank(method="dense", ascending=False)
)
#Top 5 Categories
top_categories = (
    product_mix[product_mix["rank"] <= 5]
    .sort_values(
        ["customer_value_segment", "rank"]
    )
)

print(top_categories)
# %% AVG FREIGHT COST % BY CUSTOMER VALUE SEGMENT TO CHECK IF HIGH MARGIN CUSTOMERS HAVE LOW FREIGHT COST BURDEN
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query = """
SELECT
    c.customer_value_segment,
    o.order_id,
    SUM(ot.gross_sales) AS gross_sales,
    SUM(ot.total_freight) AS total_freight
FROM orders_fact o

INNER JOIN customers_dim c
    ON o.customer_id = c.customer_id

INNER JOIN order_items_fact ot
    ON o.order_id = ot.order_id

WHERE c.customer_value_segment IS NOT NULL

GROUP BY
    c.customer_value_segment,
    o.order_id
"""

df = pd.read_sql(query, engine)

#Calculate Freight %
df["freight_pct"] = (
    df["total_freight"] /
    df["gross_sales"]
) * 100

#Aggregate by Customer Segment
result = (
    df.groupby("customer_value_segment")
      .agg(
          avg_freight_pct=("freight_pct", "mean"),
          avg_order_value=("gross_sales", "mean"),
          avg_freight_cost=("total_freight", "mean"),
          orders=("order_id", "count")
      )
      .round(2)
      .reset_index()
)

print(result)
# %% HOW MANY ITEMS ON AVERAGE IS PURCHASED BY THE CUSTOMER VALUE SEGMENTS ON EACH ORDER

import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
   "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query = """
SELECT
    c.customer_value_segment,
    o.order_id,
    COUNT(ot.order_item_id) AS items_per_order
FROM orders_fact o

INNER JOIN customers_dim c
    ON o.customer_id = c.customer_id

INNER JOIN order_items_fact ot
    ON o.order_id = ot.order_id

WHERE c.customer_value_segment IS NOT NULL

GROUP BY
    c.customer_value_segment,
    o.order_id
"""

df = pd.read_sql(query, engine)

result = (
    df.groupby("customer_value_segment")
      .agg(
          avg_items_per_order=("items_per_order", "mean"),
          total_orders=("order_id", "count")
      )
      .round(2)
      .reset_index()
)

print(result)

# %% ARE HIGH VALUE CUSTOMERS HAVING FASTER DELIVERY AND HIGHER REVIEW SCORES

import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
   "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)
query = """
SELECT
    c.customer_value_segment,
    o.order_id,
    o.delivery_days,
    r.review_score
FROM orders_fact o

INNER JOIN customers_dim c
    ON o.customer_id = c.customer_id

LEFT JOIN order_reviews_fact r
    ON o.order_id = r.order_id

WHERE c.customer_value_segment IS NOT NULL
"""

df = pd.read_sql(query, engine)

result = (
    df.groupby("customer_value_segment")
      .agg(
          avg_delivery_days=("delivery_days", "mean"),
          avg_review_score=("review_score", "mean"),
          total_orders=("order_id", "count")
      )
      .round(2)
      .reset_index()
)

print(result)

# %% REGRESSION ON FREIGHT COST PCT AND PROFIT MARGIN

import pandas as pd
from sqlalchemy import create_engine
from sklearn.linear_model import LinearRegression

engine = create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query = """
SELECT 
    (total_freight / NULLIF(gross_sales, 0)) * 100 AS freight_cost_pct,
    profit_margin_pct
FROM order_items_fact 
WHERE total_freight IS NOT NULL AND gross_sales IS NOT NULL AND gross_sales > 0
"""

df = pd.read_sql(query, engine)

x = df[['freight_cost_pct']]
y = df['profit_margin_pct']

model = LinearRegression()
model.fit(x, y)

print("Intercept:", model.intercept_)
print("Coefficient:", model.coef_[0])
print("R2:", model.score(x, y))

# %% REGRESSION OF COGS % AND PROFIT MARGIN

import pandas as pd
from sqlalchemy import create_engine
from sklearn.linear_model import LinearRegression

engine = create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query = """
SELECT 
    (total_cogs / NULLIF(gross_sales, 0)) * 100 AS cogs_pct,
    profit_margin_pct
FROM order_items_fact 
WHERE total_cogs IS NOT NULL AND gross_sales IS NOT NULL AND gross_sales > 0
"""

df = pd.read_sql(query, engine)

x = df[['cogs_pct']]
y = df['profit_margin_pct']

model = LinearRegression()
model.fit(x, y)

print("Intercept:", model.intercept_)
print("Coefficient:", model.coef_[0])
print("R2:", model.score(x, y))

# %%
