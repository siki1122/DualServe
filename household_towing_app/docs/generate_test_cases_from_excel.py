import pandas as pd
import csv

def format_steps(text):
    if pd.isna(text) or str(text).strip() == 'nan' or not str(text).strip():
        return ""
    text_str = str(text).strip()
    # Check if already numbered
    if text_str.startswith('1.') or text_str.startswith('1)'):
        return text_str
    
    # If there are newlines, treat each line as a step
    if '\n' in text_str:
        lines = text_str.split('\n')
        return "\n".join([f"{i+1}. {line.strip()}" for i, line in enumerate(lines) if line.strip()])
    else:
        # Single line step
        return f"1. {text_str}"

def generate_from_excel(input_file, output_file):
    df = pd.read_excel(input_file)
    
    headers = [
        "id", "title", "description", "preconditions", "postconditions", "tags",
        "priority", "severity", "type", "behavior", "automation", "status",
        "is_flaky", "layer", "steps_type", "steps_actions", "steps_result",
        "steps_data", "milestone_id", "milestone", "suite_id", "suite_parent_id",
        "suite", "suite_without_cases", "parameters", "is_muted"
    ]
    
    cases = []
    current_suite = "General"
    suite_id = 1
    case_id = 1
    
    for index, row in df.iterrows():
        tc_id = str(row['TEST CASE ID']).strip()
        
        # Check if it's a suite row (TEST DESCRIPTION is empty)
        if pd.isna(row['TEST DESCRIPTION']) or str(row['TEST DESCRIPTION']).strip() == 'nan' or str(row['TEST DESCRIPTION']).strip() == '':
            if tc_id != 'nan' and tc_id != '':
                # Extract suite name
                if ':' in tc_id:
                    current_suite = tc_id.split(':', 1)[1].strip()
                else:
                    current_suite = tc_id
                
                # Add suite row
                cases.append({
                    k: "" for k in headers
                })
                cases[-1]["suite_id"] = suite_id
                cases[-1]["suite"] = current_suite
                cases[-1]["suite_without_cases"] = "1"
                
                suite_id += 1
            continue
            
        # It's a test case row
        title = str(row['TEST DESCRIPTION']).strip()
        expected_outcome = row['EXPECTED OUTCOME']
        
        steps_actions = format_steps(title)
        steps_result = format_steps(expected_outcome)
        
        behavior = "positive"
        if "invalid" in title.lower() or "empty" in title.lower() or "fail" in title.lower() or "error" in title.lower():
            behavior = "negative"
            
        # Create case dict initialized with empty strings
        case_dict = {k: "" for k in headers}
        
        case_dict.update({
            "id": case_id,
            "title": tc_id + " - " + title[:50] + ("..." if len(title) > 50 else ""),
            "description": title,
            "priority": "normal",
            "severity": "normal",
            "type": "functional",
            "behavior": behavior,
            "automation": "is-not-automated",
            "status": "draft",
            "is_flaky": "no",
            "layer": "e2e",
            "steps_type": "classic",
            "steps_actions": steps_actions,
            "steps_result": steps_result,
            "suite": current_suite,
            "is_muted": "no"
        })
        
        cases.append(case_dict)
        case_id += 1

    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=headers)
        writer.writeheader()
        for c in cases:
            writer.writerow(c)
            
    print(f"Generated {output_file} with {case_id - 1} test cases across {suite_id - 1} suites.")

generate_from_excel(
    r'c:\code\DUALSERVE\household_towing_app\docs\testcasesqase.xlsx',
    r'c:\code\DUALSERVE\household_towing_app\docs\Qase_Test_Cases_Excel.csv'
)
