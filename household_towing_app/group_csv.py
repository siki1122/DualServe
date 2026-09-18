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
        if len(row) > 1:
            rows.append(row)

# Function to determine use case
def determine_usecase(desc, segment):
    desc_lower = desc.lower()
    
    if 'auth' in desc_lower or 'login' in desc_lower or 'sign' in desc_lower:
        return 'Authentication & Security'
    elif 'register' in desc_lower or 'user' in desc_lower and 'profile' in desc_lower:
        return 'User Registration & Profiles'
    elif 'book' in desc_lower or 'task' in desc_lower:
        return 'Booking & Task Management'
    elif 'bill' in desc_lower or 'transact' in desc_lower or 'price' in desc_lower or 'night' in desc_lower:
        return 'Billing & Pricing Engine'
    elif 'asset' in desc_lower or 'provider' in desc_lower:
        return 'Asset & Provider Management'
    elif 'validat' in desc_lower:
        return 'Form Data Validation'
    elif 'route' in desc_lower or 'distanc' in desc_lower or 'radius' in desc_lower or 'location' in desc_lower:
        return 'Geolocation & Routing'
    else:
        return 'Core System Components'

# Update header
if 'Use Case' not in header:
    header.insert(1, 'Use Case')

# Update rows with Use Case
for row in rows:
    tc_id = row[0]
    segment = row[2] if len(row) > 2 else ''
    desc = row[3] if len(row) > 3 else ''
    
    # if the row already has the use case in [1], desc is in [3]
    use_case = determine_usecase(desc, segment)
    
    if len(row) == 7: 
        row.insert(1, use_case)
    else:
        row[1] = use_case

# Define logical system order
system_order = {
    'Authentication & Security': 1,
    'User Registration & Profiles': 2,
    'Form Data Validation': 3,
    'Geolocation & Routing': 4,
    'Booking & Task Management': 5,
    'Asset & Provider Management': 6,
    'Billing & Pricing Engine': 7,
    'Core System Components': 8
}

# Sort rows by Logical System Order
rows.sort(key=lambda x: system_order.get(x[1], 99))

# Re-number TC IDs so they are sequential after sorting
for i, row in enumerate(rows, 1):
    row[0] = f'TC-{i:03d}'

# Write back to CSV
with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows(rows)

print(f"Added Use Case column and grouped {len(rows)} tests logically!")
