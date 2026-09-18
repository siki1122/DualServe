import csv
import re
import os

file_path = 'alpha_test_table.csv'
temp_path = 'alpha_test_table_col.csv'

with open(file_path, mode='r', encoding='utf-8') as infile, open(temp_path, mode='w', encoding='utf-8', newline='') as outfile:
    reader = csv.reader(infile)
    writer = csv.writer(outfile)
    
    headers = next(reader)
    if "Duration" not in headers:
        headers.append("Duration")
    writer.writerow(headers)
    
    for row in reader:
        # row[6] is Actual Behavior
        if len(row) > 6:
            actual_behavior = row[6]
            match = re.search(r'\(Duration:\s*(\d+)\s*ms\)', actual_behavior)
            
            duration_val = ""
            if match:
                duration_val = f"{match.group(1)} ms"
                # Strip the duration from Actual Behavior
                row[6] = re.sub(r'\s*\(Duration:\s*\d+\s*ms\)', '', actual_behavior).strip()
            
            # Make sure the row has the same number of columns as the header
            while len(row) < len(headers) - 1:
                row.append("")
                
            if len(row) == len(headers) - 1:
                row.append(duration_val)
            else:
                row[8] = duration_val # index 8 is the 9th column (Duration)
        
        writer.writerow(row)

os.replace(temp_path, file_path)
print("Successfully moved duration into a new column.")
