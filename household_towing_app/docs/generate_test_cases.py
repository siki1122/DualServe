import zipfile
import xml.etree.ElementTree as ET
import csv
import re

def parse_docx(file_path):
    z = zipfile.ZipFile(file_path)
    xml_content = z.read('word/document.xml')
    tree = ET.fromstring(xml_content)
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    text = '\n'.join([node.text for node in tree.findall('.//w:t', ns) if node.text])
    return text

def extract_steps(flow_text):
    if not flow_text:
        return ""
    # Find all 'Step X:' (with optional spaces around colon) and split the text
    parts = re.split(r'Step \d+\s*:\s*', flow_text)
    steps = [p.strip() for p in parts if p.strip()]
    
    clean_steps = []
    for i, s in enumerate(steps):
        clean_s = s.replace('\n', ' ').strip()
        clean_steps.append(f"{i+1}. {clean_s}")
    
    return "\n".join(clean_steps)

def generate_csv(text, output_file):
    use_case_pattern = re.compile(r'Use Case \d+: (.*?)\nUse Case Goal\s*:\s*(.*?)\n.*?Actor:\s*(.*?)\nPre-condition\s*:\s*(.*?)\n(Main Flow:.*?)(?=Use Case \d+:|$)', re.DOTALL)
    
    use_cases = use_case_pattern.findall(text)
    
    headers = [
        "id", "title", "description", "preconditions", "postconditions", "tags",
        "priority", "severity", "type", "behavior", "automation", "status",
        "is_flaky", "layer", "steps_type", "steps_actions", "steps_result",
        "steps_data", "milestone_id", "milestone", "suite_id", "suite_parent_id",
        "suite", "suite_without_cases", "parameters", "is_muted"
    ]
    
    cases = []
    case_id = 1
    suite_id = 1
    
    for uc in use_cases:
        title = uc[0].strip()
        goal = uc[1].strip()
        actor = uc[2].strip()
        precondition = uc[3].strip()
        flows_text = uc[4]
        
        suite_name = title
        
        # 1. Add the suite row
        cases.append({
            "id": "", "title": "", "description": "", "preconditions": "", "postconditions": "",
            "tags": "", "priority": "", "severity": "", "type": "", "behavior": "",
            "automation": "", "status": "", "is_flaky": "", "layer": "", "steps_type": "",
            "steps_actions": "", "steps_result": "", "steps_data": "", "milestone_id": "",
            "milestone": "", 
            "suite_id": suite_id, 
            "suite_parent_id": "", 
            "suite": suite_name, 
            "suite_without_cases": "1", 
            "parameters": "", "is_muted": ""
        })
        
        # 2. Main Flow
        main_flow_match = re.search(r'Main Flow:(.*?)(Alternative Flow:|Alternative:|Exception:|User Action:|$)', flows_text, re.DOTALL)
        if main_flow_match:
            main_flow = main_flow_match.group(1).strip()
            steps_actions = extract_steps(main_flow)
            
            if steps_actions:
                cases.append({
                    "id": case_id,
                    "title": f"Main Flow",
                    "description": goal,
                    "preconditions": precondition,
                    "postconditions": "",
                    "tags": "actor:" + actor.replace(' ', '_'),
                    "priority": "normal",
                    "severity": "normal",
                    "type": "functional",
                    "behavior": "positive",
                    "automation": "is-not-automated",
                    "status": "draft",
                    "is_flaky": "no",
                    "layer": "e2e",
                    "steps_type": "classic",
                    "steps_actions": steps_actions,
                    "steps_result": "",
                    "steps_data": "",
                    "milestone_id": "",
                    "milestone": "",
                    "suite_id": "",
                    "suite_parent_id": "",
                    "suite": suite_name,
                    "suite_without_cases": "",
                    "parameters": "",
                    "is_muted": "no"
                })
                case_id += 1
        
        # 3. Alternative flows
        alt_flow_match = re.search(r'(Alternative Flow:|Alternative:)(.*?)(Exception:|User Action:|$)', flows_text, re.DOTALL)
        if alt_flow_match:
            alt_flow = alt_flow_match.group(2).strip()
            alt_steps_actions = extract_steps(alt_flow)
            
            if alt_steps_actions:
                cases.append({
                    "id": case_id,
                    "title": f"Alternative Flow",
                    "description": goal,
                    "preconditions": precondition,
                    "postconditions": "",
                    "tags": "actor:" + actor.replace(' ', '_'),
                    "priority": "normal",
                    "severity": "normal",
                    "type": "functional",
                    "behavior": "negative",
                    "automation": "is-not-automated",
                    "status": "draft",
                    "is_flaky": "no",
                    "layer": "e2e",
                    "steps_type": "classic",
                    "steps_actions": alt_steps_actions,
                    "steps_result": "",
                    "steps_data": "",
                    "milestone_id": "",
                    "milestone": "",
                    "suite_id": "",
                    "suite_parent_id": "",
                    "suite": suite_name,
                    "suite_without_cases": "",
                    "parameters": "",
                    "is_muted": "no"
                })
                case_id += 1
                
        # 4. Exception flows
        exc_flow_match = re.search(r'(Exception:)(.*?)(User Action:|$)', flows_text, re.DOTALL)
        if exc_flow_match:
            exc_flow = exc_flow_match.group(2).strip()
            exc_steps_actions = extract_steps(exc_flow)
            
            if exc_steps_actions:
                cases.append({
                    "id": case_id,
                    "title": f"Exception Flow",
                    "description": goal,
                    "preconditions": precondition,
                    "postconditions": "",
                    "tags": "actor:" + actor.replace(' ', '_'),
                    "priority": "normal",
                    "severity": "normal",
                    "type": "functional",
                    "behavior": "negative",
                    "automation": "is-not-automated",
                    "status": "draft",
                    "is_flaky": "no",
                    "layer": "e2e",
                    "steps_type": "classic",
                    "steps_actions": exc_steps_actions,
                    "steps_result": "",
                    "steps_data": "",
                    "milestone_id": "",
                    "milestone": "",
                    "suite_id": "",
                    "suite_parent_id": "",
                    "suite": suite_name,
                    "suite_without_cases": "",
                    "parameters": "",
                    "is_muted": "no"
                })
                case_id += 1
        
        suite_id += 1

    with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=headers)
        writer.writeheader()
        for c in cases:
            writer.writerow(c)

text = parse_docx(r'c:\code\DUALSERVE\household_towing_app\docs\testcase.docx')
generate_csv(text, r'c:\code\DUALSERVE\household_towing_app\docs\Qase_Test_Cases_Scenarios.csv')
print(f"Generated {r'c:\code\DUALSERVE\household_towing_app\docs\Qase_Test_Cases_Scenarios.csv'}")
