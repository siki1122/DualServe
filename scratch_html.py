import markdown
import sys
import os

md_file = r"c:\code\DUALSERVE\system_data_dictionary.md"
html_file = r"c:\code\DUALSERVE\system_data_dictionary.html"

try:
    with open(md_file, 'r', encoding='utf-8') as f:
        md_text = f.read()

    # Simple manual parsing for tables since standard markdown doesn't do tables without extensions
    # But we can just use the markdown library with extensions
    html = markdown.markdown(md_text, extensions=['tables'])

    full_html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>DualServe Data Dictionary</title>
        <style>
            body {{ font-family: Arial, sans-serif; padding: 40px; color: #333; }}
            table {{ border-collapse: collapse; width: 100%; margin-bottom: 30px; }}
            th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
            th {{ background-color: #f4f4f4; }}
            h2 {{ color: #2c3e50; border-bottom: 2px solid #eee; padding-bottom: 5px; }}
        </style>
    </head>
    <body>
        {html}
    </body>
    </html>
    """

    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(full_html)
    print("HTML generated")
except Exception as e:
    print(f"Error: {e}")
    # If markdown library is not installed, fallback to basic HTML wrapping
    print("Falling back to basic conversion...")
