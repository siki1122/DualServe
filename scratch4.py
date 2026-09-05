import os
import re

model_dir = r"c:\code\DUALSERVE\household_towing_app\lib\models"
output_md = r"c:\code\DUALSERVE\system_data_dictionary.md"

markdown_content = """# DualServe Complete Data Dictionary

This document outlines the complete data structures for the DualServe system.

"""

def infer_format(field_name, field_type):
    name = field_name.lower()
    if 'email' in name:
        return 'Email format', '255'
    if 'url' in name or 'image' in name:
        return 'URL', '255'
    if 'id' in name and len(name) == 2 or name.endswith('id'):
        return 'Alphanumeric', 'Varies'
    if 'date' in name or 'time' in name or 'at' in name or field_type == 'DateTime':
        return 'ISO 8601', '—'
    if 'status' in name or 'type' in name or 'role' in name or field_type not in ['String', 'int', 'double', 'bool', 'DateTime', 'String?', 'int?', 'double?', 'bool?', 'DateTime?']:
        if field_type.startswith('List') or field_type.startswith('Map'):
            return 'JSON/Array', 'Varies'
        if 'String' not in field_type and 'int' not in field_type and 'double' not in field_type and 'bool' not in field_type:
            return 'Enum/Custom', 'Varies'
        return 'Enum', 'Varies'
    if 'String' in field_type:
        if 'phone' in name:
            return 'Numeric/String', '11-15'
        return 'Text', '100-255'
    if 'int' in field_type or 'double' in field_type:
        return 'Numeric', '—'
    if 'bool' in field_type:
        return 'Boolean', '—'
    return 'Varies', 'Varies'

def infer_description(field_name, class_name):
    lower_name = field_name.lower()
    desc_map = {
        'id': 'Unique identifier for this document.',
        'createdat': 'Timestamp of when the record was initially created.',
        'updatedat': 'Timestamp of when the record was last modified.',
        'status': f'Current status lifecycle state of the {class_name}.',
        'latitude': 'Geographic latitude coordinate.',
        'longitude': 'Geographic longitude coordinate.',
        'customerid': 'Reference ID to the associated Customer.',
        'providerid': 'Reference ID to the associated Provider.',
        'driverid': 'Reference ID to the assigned Driver.',
        'taskid': 'Reference ID to the associated Task.',
        'bookingid': 'Reference ID to the associated Booking.',
        'servicetype': 'Category or type of service requested (e.g., Towing, Household).',
        'name': f'Full name or title of the {class_name}.',
        'email': 'Primary email address used for contact/authentication.',
        'phone': 'Primary contact phone number.',
        'address': 'Physical address text.',
        'notes': 'Additional context, instructions, or remarks.',
        'rating': 'Average or given score (e.g., out of 5).',
        'isread': 'Boolean flag indicating if a message/notification has been viewed.',
        'progress': 'Completion percentage or fractional progress (0.0 to 1.0).',
        'iscompleted': 'Boolean flag indicating successful completion.',
        'category': 'High-level grouping classification.',
        'baseprice': 'Starting base cost before additions or multipliers.',
        'finalcost': 'Total computed final cost charged to the customer.',
        'distance': 'Calculated geographic distance.',
    }
    
    if lower_name in desc_map:
        return desc_map[lower_name]
    
    # Generate generic description based on camelCase
    words = re.findall(r'[A-Z]?[a-z]+|[A-Z]+(?=[A-Z]|$)', field_name)
    sentence = " ".join(words).capitalize()
    return f"{sentence} detail associated with the {class_name}."

for filename in os.listdir(model_dir):
    if not filename.endswith('.dart'):
        continue
        
    filepath = os.path.join(model_dir, filename)
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Find all classes
    class_pattern = re.compile(r'class\s+(\w+)\s*{([^}]*)}', re.MULTILINE | re.DOTALL)
    for class_match in class_pattern.finditer(content):
        class_name = class_match.group(1)
        body = class_match.group(2)
        
        # Only parse classes that look like data models (have fields)
        fields = re.findall(r'^\s*final\s+([A-Za-z0-9_\<\>\?]+)\s+([A-Za-z0-9_]+)\s*;', body, re.MULTILINE)
        if not fields:
            continue
            
        markdown_content += f"## {class_name} Data Table\n"
        markdown_content += "| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |\n"
        markdown_content += "| :--- | :--- | :--- | :--- | :--- |\n"
        for field_type, field_name in fields:
            fmt, length = infer_format(field_name, field_type)
            clean_type = field_type.replace('?', '')
            if clean_type == 'DateTime':
                clean_type = 'Timestamp'
            
            desc = infer_description(field_name, class_name)
            
            markdown_content += f"| {field_name} | {clean_type} | {fmt} | {length} | {desc} |\n"
        markdown_content += "\n"
        
with open(output_md, 'w', encoding='utf-8') as f:
    f.write(markdown_content)
    
print("Data dictionary generated with new columns and descriptions!")
