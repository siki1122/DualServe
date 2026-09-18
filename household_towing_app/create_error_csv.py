import csv
import os

source_csv = r'c:\code\DUALSERVE\household_towing_app\alpha_test_table.csv'
dest_csv = r'c:\code\DUALSERVE\household_towing_app\alpha_test_table_with_errors.csv'

rows = []
with open(source_csv, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        rows.append(row)

# Find the login screen test and make it fail
# Format: [TC-ID, Use Case, Segment, Desc, Input, Expected, Actual, Result]
for row in rows:
    desc = row[3].lower()
    if 'login' in desc and 'widget' in row[2].lower():
        # Modify this row to reflect the Firebase error
        row[6] = 'Throws FirebaseException: [core/no-app] No Firebase App has been created'
        row[7] = 'Fail'
        break

# Write to new file
with open(dest_csv, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows(rows)

print("Created error table successfully!")
