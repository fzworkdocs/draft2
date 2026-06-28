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

# %%
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
INNER JOIN customers_dim c ON c.customer_id=c.customer_id
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

# %%
