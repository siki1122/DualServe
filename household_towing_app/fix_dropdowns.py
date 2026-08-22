import os
import re

lib_dir = "c:\\code\\DUALSERVE\\household_towing_app\\lib"

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all DropdownButton and DropdownButtonFormField and add isExpanded: true
    # We will use regex to find them, and if the block inside doesn't have isExpanded: true, we add it.
    
    pattern = re.compile(r'(DropdownButton(?:FormField)?(?:<[^>]+>)?\()', re.MULTILINE)
    
    offset = 0
    new_content = ""
    changed = False
    
    for match in pattern.finditer(content):
        start = match.end()
        new_content += content[offset:start]
        offset = start
        
        # Look ahead 500 characters to see if isExpanded is there before the next widget
        lookahead = content[start:start+500]
        if 'isExpanded:' not in lookahead:
            new_content += "\n                          isExpanded: true,"
            changed = True

    new_content += content[offset:]

    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated: {filepath}")

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

print("Done.")
