import pandas as pd
from sqlalchemy import create_engine

engine=create_engine(
    "postgresql+psycopg2://postgres:faizasweety66@localhost:5432/project2"
)

query="""
SELECT 
FROM
"""
df=pd.read_sql(query,engine)

print(df.head())
print(df.shape)
print(df.describe())