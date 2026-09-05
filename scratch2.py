import os
import re

lib_dir = r"c:\code\DUALSERVE\household_towing_app\lib"
collections = set()

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            with open(os.path.join(root, file), 'r', encoding='utf-8') as f:
                content = f.read()
                matches = re.findall(r'\.collection\([\'"]([^\'"]+)[\'"]\)', content)
                collections.update(matches)

print(f"Total Unique Collections: {len(collections)}")
for c in sorted(collections):
    print(c)
