import os
import re

def process_directory(directory):
    replacements = [
        # Note: Order matters. More specific ones first.
        (r'Colors\.grey\[100\]!', r'AppTheme.surfaceLight'),
        (r'Colors\.grey\[100\]', r'AppTheme.surfaceLight'),
        (r'Colors\.grey\[50\]!', r'AppTheme.surfaceLight'),
        (r'Colors\.grey\[50\]', r'AppTheme.surfaceLight'),
        
        (r'Colors\.grey\[300\]!', r'AppTheme.textSlateLight'),
        (r'Colors\.grey\[300\]', r'AppTheme.textSlateLight'),
        (r'Colors\.grey\[200\]!', r'AppTheme.textSlateLight.withValues(alpha: 0.5)'),
        (r'Colors\.grey\[200\]', r'AppTheme.textSlateLight.withValues(alpha: 0.5)'),
        
        (r'Colors\.grey\.withOpacity\(0\.2\)', r'AppTheme.textSlateMedium.withValues(alpha: 0.2)'),
        (r'Colors\.grey\.withValues\(alpha:\s*0\.2\)', r'AppTheme.textSlateMedium.withValues(alpha: 0.2)'),
        
        # We leave Colors.white alone mostly for contrast, except where explicitly needed, but the plan 
        # says "keep for contrast OR AppTheme.surface". Let's leave Colors.white intact for safety.
        
        (r'Colors\.black87!', r'AppTheme.textSlateDark'),
        (r'Colors\.black87', r'AppTheme.textSlateDark'),
        (r'Colors\.black!', r'AppTheme.textSlateDark'),
        (r'Colors\.black\b(?!54|12|26|87)', r'AppTheme.textSlateDark'),
        
        (r'Colors\.blue\[50\]!', r'AppTheme.primaryBlue.withValues(alpha: 0.1)'),
        (r'Colors\.blue\[50\]', r'AppTheme.primaryBlue.withValues(alpha: 0.1)'),
        (r'Colors\.green\[50\]!', r'AppTheme.towingOrange.withValues(alpha: 0.1)'),
        (r'Colors\.green\[50\]', r'AppTheme.towingOrange.withValues(alpha: 0.1)'),
        
        (r'Colors\.blue\[700\]!', r'AppTheme.primaryBlue'),
        (r'Colors\.blue\[700\]', r'AppTheme.primaryBlue'),
        (r'Colors\.green\[700\]!', r'AppTheme.towingOrange'),
        (r'Colors\.green\[700\]', r'AppTheme.towingOrange'),
        
        (r'Colors\.green\[100\]!', r'AppTheme.statusCompletedBg'),
        (r'Colors\.green\[100\]', r'AppTheme.statusCompletedBg'),
        
        # General colors
        (r'Colors\.grey\b(?!\[|\.)', r'AppTheme.textSlateMedium'),
        (r'Colors\.blue\b(?!\[|\.)', r'AppTheme.primaryBlue'),
        (r'Colors\.orange\b(?!\[|\.)', r'AppTheme.towingOrange'),
        (r'Colors\.green\b(?!\[|\.)', r'AppTheme.statusCompletedText'), 
        
        # Force unwraps
        (r'Colors\.blue\[[0-9]+\]!', r'AppTheme.primaryBlue'),
        (r'Colors\.orange\[[0-9]+\]!', r'AppTheme.towingOrange'),
        (r'Colors\.green\[[0-9]+\]!', r'AppTheme.statusCompletedText'),
    ]

    import_statement = "import 'package:household_towing_app/utils/app_theme.dart';\n"
    modified_files_count = 0

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart') and file != 'app_theme.dart' and file != 'color_mapping_guide.txt':
                file_path = os.path.join(root, file)
                
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                original_content = content
                
                # Perform all replacements
                for pattern, replacement in replacements:
                    content = re.sub(pattern, replacement, content)
                
                # If something changed, check for AppTheme import
                if content != original_content:
                    if 'import \'package:household_towing_app/utils/app_theme.dart\';' not in content and 'AppTheme' in content:
                        # Find the last import statement and inject it after
                        import_match = list(re.finditer(r"^import\s+['\"].*?['\"];$", content, re.MULTILINE))
                        if import_match:
                            last_import_pos = import_match[-1].end()
                            content = content[:last_import_pos] + "\n" + import_statement + content[last_import_pos:]
                        else:
                            content = import_statement + "\n" + content
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    
                    modified_files_count += 1
                    print(f"Modified: {file_path}")

    print(f"Successfully modified {modified_files_count} files.")

if __name__ == "__main__":
    lib_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'lib')
    process_directory(lib_dir)
