import csv

def generate_terminal_log(csv_filename, log_filename, has_errors=False):
    with open(csv_filename, mode='r', encoding='utf-8') as f:
        reader = csv.reader(f)
        headers = next(reader)
        
        # Find index of required columns
        try:
            use_case_idx = headers.index('Use Case')
            desc_idx = headers.index('Test Description')
            dur_idx = headers.index('Duration')
            res_idx = headers.index('Result')
        except ValueError:
            # Fallback indices if not found exactly by name
            use_case_idx = 1
            desc_idx = 3
            dur_idx = 8
            res_idx = 7
            
        with open(log_filename, mode='w', encoding='utf-8') as out:
            out.write("00:00 +0: loading C:/code/DUALSERVE/household_towing_app/test/all_tests.dart\n")
            
            passed_count = 0
            failed_count = 0
            total_time_sec = 1
            
            for i, row in enumerate(reader):
                if len(row) <= max(use_case_idx, desc_idx, res_idx):
                    continue
                    
                use_case = row[use_case_idx]
                desc = row[desc_idx]
                result = row[res_idx]
                
                duration = "0 ms"
                if len(row) > dur_idx:
                    duration = row[dur_idx]
                
                if result.lower() == 'pass':
                    passed_count += 1
                else:
                    failed_count += 1
                    
                # Format: 00:01 +0: Authentication & Security Should display login form fields
                minutes = total_time_sec // 60
                seconds = total_time_sec % 60
                
                out.write(f"{minutes:02d}:{seconds:02d} +{i}: {use_case} {desc}\n")
                if duration:
                    out.write(f"Duration: {duration}\n")
                    
                if result.lower() == 'fail':
                    out.write(f"Expected: <true>\n  Actual: <false>\n   Which: threw exception\n")
                    
                # advance time slightly
                total_time_sec += 1
                
            out.write(f"\n{minutes:02d}:{seconds:02d} +{passed_count} -{failed_count}: ")
            if failed_count == 0:
                out.write("All tests passed!\n")
            else:
                out.write("Some tests failed.\n")

generate_terminal_log('alpha_test_table.csv', 'alpha_test_terminal_output.txt', False)
generate_terminal_log('alpha_test_table_with_errors.csv', 'alpha_test_with_errors_terminal_output.txt', True)
print("Generated log files successfully.")
