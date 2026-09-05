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
            markdown_content += f"| {field_name} | {clean_type} | {fmt} | {length} | |\n"
        markdown_content += "\n"
        
with open(output_md, 'w', encoding='utf-8') as f:
    f.write(markdown_content)
    
print("Data dictionary generated with new columns!")
