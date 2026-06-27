"""
STEP 2 — LOAD THE WORLD TOUR CSVs INTO STAGING TABLES
-----------------------------------------------------
Loads the five BWF World Tour discipline files into raw staging tables in
BadmintonDB. "Staging" = a raw landing zone. We don't clean anything here and
we don't touch your real 18-table schema yet.

NOTE: We are deliberately NOT loading bwf-ss-gamedata-2015-2017-new.csv.
That Super Series file has no player names (only country-vs-country point logs),
so it doesn't fit a player-performance database. Set aside for now.

USAGE:
  python 02_load_staging.py

After it runs, refresh BadmintonDB in SSMS -> Tables. You'll see:
  stg_ms, stg_ws, stg_md, stg_wd, stg_xd
"""

import pandas as pd
import os
import urllib
from sqlalchemy import create_engine

# Your real folder, already filled in:
CSV_FOLDER = r"C:\Users\dariu\Downloads\badmintonData"

# Each CSV file -> the staging table it lands in.
FILES_TO_LOAD = {
    "ms.csv": "stg_ms",   # men's singles
    "ws.csv": "stg_ws",   # women's singles
    "md.csv": "stg_md",   # men's doubles
    "wd.csv": "stg_wd",   # women's doubles
    "xd.csv": "stg_xd",   # mixed doubles
}

SERVER   = r"MSI\SQLEXPRESS"
DATABASE = "BadmintonDB"

conn_str = (
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;"
)
params = urllib.parse.quote_plus(conn_str)
engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={params}",
    fast_executemany=True,
)

for file_name, table_name in FILES_TO_LOAD.items():
    path = os.path.join(CSV_FOLDER, file_name)
    if not os.path.exists(path):
        print(f"SKIP - file not found: {path}")
        continue

    print(f"Loading {file_name} -> {table_name} ...")
    df = pd.read_csv(path)
    df["source_file"] = file_name   # remember where each row came from

    df.to_sql(
        table_name,
        engine,
        if_exists="replace",   # drop & reload each run = safe to re-run
        index=False,
        chunksize=1000,
    )
    print(f"   done: {len(df):,} rows -> {table_name}")

print("\nAll five World Tour staging tables loaded. Check them in SSMS.")
