import pandas as pd

df = pd.read_excel(r'c:\code\DUALSERVE\household_towing_app\docs\testcasesqase.xlsx')

# Print the columns
print("Columns in Excel:")
print(df.columns.tolist())

# Print a few rows
print("\nFirst 10 rows:")
print(df.head(10).to_string())
