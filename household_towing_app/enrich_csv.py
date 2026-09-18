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

# Function to infer realistic input and expected behavior based on the test description
def infer_details(segment, desc):
    desc_lower = desc.lower()
    
    # Defaults
    input_val = 'Mock Data'
    expected = 'Should execute properly'
    
    # 1. Widgets / Screens
    if segment == 'Widget':
        if 'login' in desc_lower:
            input_val = 'email="test@email.com", pass="password123"'
            expected = 'Should authenticate and route to dashboard'
        elif 'register' in desc_lower:
            input_val = 'name="John Doe", email="test@email.com", role="Customer"'
            expected = 'Should create account and route to home'
        else:
            input_val = 'Widget Render Context'
            expected = 'Should render without errors and display UI elements'
            
    # 2. Form Validators
    elif 'validator' in desc_lower or 'validate' in desc_lower:
        if 'email' in desc_lower:
            input_val = '"invalid-email"' if 'reject' in desc_lower else '"user@example.com"'
        elif 'password' in desc_lower:
            input_val = '"123"' if 'reject' in desc_lower else '"StrongPass123!"'
        elif 'phone' in desc_lower:
            input_val = '"0912"' if 'reject' in desc_lower else '"+639123456789"'
        else:
            input_val = '"" (Empty String)' if 'empty' in desc_lower else '"Valid String"'
            
        expected = 'Returns validation error string' if 'reject' in desc_lower else 'Returns null (valid)'
        
    # 3. Models (Firestore parsing)
    elif segment == 'Model':
        if 'parse' in desc_lower or 'from firestore' in desc_lower:
            input_val = '{"id": "doc_123", "status": "active", "createdAt": Timestamp}'
            expected = 'Should correctly map JSON to Model object properties'
        elif 'tofirestore' in desc_lower or 'to map' in desc_lower:
            input_val = 'Valid Model Instance'
            expected = 'Should output valid JSON map for database'
        elif 'copywith' in desc_lower:
            input_val = 'New parameter values (e.g., status="completed")'
            expected = 'Should return new Model instance with updated fields'
            
    # 4. Services (Business Logic)
    elif segment == 'Service':
        if 'signout' in desc_lower:
            input_val = 'Active User Session'
            expected = 'Should clear session and sign out from Firebase'
        elif 'signin' in desc_lower or 'auth' in desc_lower:
            input_val = 'GoogleSignInAccount credentials'
            expected = 'Should authenticate with Firebase and return UserCredential'
        elif 'distance' in desc_lower or 'location' in desc_lower:
            input_val = 'Lat(14.5995), Lng(120.9842)'
            expected = 'Should calculate and return accurate geospatial data'
        elif 'route' in desc_lower:
            input_val = 'Start Coordinates, Destination Coordinates'
            expected = 'Should fetch from OSRM API and decode polyline'
        elif 'booking' in desc_lower or 'create' in desc_lower:
            input_val = 'BookingModel or TaskModel Data'
            expected = 'Should successfully write document to Firestore'
        elif 'delete' in desc_lower:
            input_val = 'Document ID="task_abc123"'
            expected = 'Should remove document or throw if dependencies exist'
            
        if 'throw' in desc_lower:
            expected = 'Should throw an Exception'
            
    # Catch-all specifics
    if 'night' in desc_lower:
        input_val = 'DateTime(2026, 9, 6, 2, 0) [2:00 AM]'
        expected = 'Should apply overnight rate multipliers'
    if 'throw' in desc_lower and 'rating' in desc_lower:
        input_val = 'rating = -1 or rating = 6'
        expected = 'Should throw "Rating must be between 0 and 5" Exception'
        
    return input_val, expected

# Update rows
updated_rows = []
for row in rows:
    tc_id, segment, desc, old_in, old_exp, act, res = row
    
    new_in, new_exp = infer_details(segment, desc)
    
    updated_rows.append([tc_id, segment, desc, new_in, new_exp, act, res])

# Write back to CSV
with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(header)
    writer.writerows(updated_rows)

print("Successfully injected realistic values into the CSV!")
