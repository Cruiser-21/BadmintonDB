"""
STEP 1 — INSPECT THE CSVs
-------------------------
Run this FIRST. It does not touch your database. It just reads every CSV
in the folder you point it at and prints:
  - the file name
  - how many rows it has
  - the exact column names
  - the first 3 rows

WHY: every Kaggle dataset names its columns differently. You cannot write the
load/transform steps until you know what the columns are actually called.
Copy the printed column names into step 3 later.

USAGE:
  1. Put your downloaded CSVs in one folder (see README, Step A).
  2. Set CSV_FOLDER below to that folder.
  3. Run:  python 01_inspect.py
"""

import pandas as pd
import glob
import os

# ---- EDIT THIS to the folder where you unzipped the Kaggle CSVs ----
CSV_FOLDER = r"C:\Users\dariu\Downloads\badmintonData"
# --------------------------------------------------------------------

csv_files = glob.glob(os.path.join(CSV_FOLDER, "*.csv"))

if not csv_files:
    print(f"No CSV files found in: {CSV_FOLDER}")
    print("Check the folder path and that the files actually end in .csv")
else:
    for path in csv_files:
        name = os.path.basename(path)
        print("=" * 70)
        print(f"FILE: {name}")
        try:
            df = pd.read_csv(path)
            print(f"ROWS: {len(df):,}   COLUMNS: {len(df.columns)}")
            print("\nCOLUMN NAMES:")
            for col in df.columns:
                print(f"   - {col}")
            print("\nFIRST 3 ROWS:")
            print(df.head(3).to_string())
        except Exception as e:
            print(f"   Could not read this file: {e}")
        print()
