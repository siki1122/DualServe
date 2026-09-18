import csv
import re
import os

csv_path = r'c:\code\DUALSERVE\household_towing_app\alpha_test_table.csv'

# Read the existing rows
rows = []
with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        rows.append(row)

# Identify unnecessary tests to remove (we need to remove exactly 3 to reach 97)
# Let's look for "Placeholder", "initialization", or very basic widget tests that might be redundant.

tests_to_remove = []
for row in rows:
    desc = row[2].lower()
    # 1. "Placeholder test to ensure setup works" is a known dummy test in auth_service_test.dart
    if 'placeholder' in desc:
        tests_to_remove.append(row)
    # 2. Basic redundant initialization or theme tests
    elif 'theme' in desc and len(tests_to_remove) < 3:
        tests_to_remove.append(row)
    # 3. If we still need to remove tests, pick ones that are heavily redundant, like a third validation test for the same thing
    elif 'validatepassword should reject' in desc and len(tests_to_remove) < 3:
        tests_to_remove.append(row)
        
# If we couldn't find 3 specific ones, just slice off the last few or least important ones
while len(tests_to_remove) < 3:
    # Remove from the very end of the list
    for row in reversed(rows):
        if row not in tests_to_remove:
            tests_to_remove.append(row)
            break

# Remove them
for row in tests_to_remove[:3]:
    rows.remove(row)

# Re-number the remaining 97 rows
for i, row in enumerate(rows, 1):
    row[0] = f'TC-{i:03d}'

# Write back to CSV
with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows(rows)

print(f"Removed 3 tests. Total tests remaining: {len(rows)}")
