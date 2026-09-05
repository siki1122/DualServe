import os
import re

model_dir = r"c:\code\DUALSERVE\household_towing_app\lib\models"
output_md = r"c:\code\DUALSERVE\system_data_dictionary.md"

markdown_content = """# DualServe Complete Data Dictionary

This document outlines the complete data structures for the DualServe system, based on all models found in `lib/models`.

"""

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
            
        markdown_content += f"## {class_name}\n"
        markdown_content += "| Field | Type | Description |\n"
        markdown_content += "| :--- | :--- | :--- |\n"
        for field_type, field_name in fields:
            markdown_content += f"| `{field_name}` | {field_type} | |\n"
        markdown_content += "\n"
        
with open(output_md, 'w', encoding='utf-8') as f:
    f.write(markdown_content)
    
print("Data dictionary generated!")
