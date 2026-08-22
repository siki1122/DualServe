import json

def restore():
    log_path = r'C:\Users\USER\.gemini\antigravity-ide\brain\072a1133-cfc1-445b-aa0e-91c0ccb0ab1f\.system_generated\logs\transcript.jsonl'
    
    # We want to find the view_file response that contains the full original file.
    # It will be a MODEL response or SYSTEM response to view_file.
    # In step 35, MODEL called view_file. In step 36, SYSTEM responded.
    
    latest_content = None
    with open(log_path, 'r', encoding='utf-8') as f:
        for line in f:
            data = json.loads(line)
            if data.get('type') == 'TOOL_RESPONSE' and 'view_file' in data.get('content', ''):
                content = data['content']
                if 'File Path: `file:///c:/code/DUALSERVE/household_towing_app/lib/screens/customer/booking_screen.dart`' in content:
                    # check if it says "Showing lines 1 to"
                    if 'Showing lines 1 to 14' in content:
                        # Extract the code
                        lines = content.split('\n')
                        extracted = []
                        is_code = False
                        for l in lines:
                            if l.startswith('1: '):
                                is_code = True
                            if 'The above content shows the entire, complete file contents' in l or 'The above content does NOT show the entire file contents' in l:
                                is_code = False
                            
                            if is_code:
                                # Remove line number "123: "
                                try:
                                    idx = l.index(': ')
                                    extracted.append(l[idx+2:])
                                except ValueError:
                                    pass
                        if extracted:
                            latest_content = '\n'.join(extracted)

    if latest_content:
        with open(r'c:\code\DUALSERVE\household_towing_app\lib\screens\customer\booking_screen.dart', 'w', encoding='utf-8') as f:
            f.write(latest_content)
        print("Restored successfully from log!")
    else:
        print("Could not find the full file in log.")

if __name__ == '__main__':
    restore()
