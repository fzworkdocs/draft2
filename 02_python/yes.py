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