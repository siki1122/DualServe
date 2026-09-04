import os
import re

files_to_clean = [
    r"lib\widgets\global_message_overlay.dart",
    r"lib\widgets\new_job_overlay.dart",
    r"lib\widgets\skeleton_loader.dart",
    r"lib\widgets\status_badge.dart",
    r"lib\widgets\success_dialog.dart",
]

for rel_path in files_to_clean:
    filepath = os.path.join(os.path.dirname(os.path.abspath(__file__)), rel_path)
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Remove duplicate imports of app_theme.dart
        import_str = "import 'package:household_towing_app/utils/app_theme.dart';\n"
        count = 0
        new_lines = []
        for line in lines:
            if line == import_str:
                count += 1
                if count > 1:
                    continue # skip duplicate
            new_lines.append(line)
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
            
print("Cleaned duplicate imports.")
